package friends

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"os"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ErrContactMatchOptedOut is returned by MatchContacts when the caller has not opted into contact
// matching. No lookup against contact_match_digests happens before this sentinel is returned.
var ErrContactMatchOptedOut = errors.New("friends: caller has not opted into contact matching")

// ErrTooManyContactDigests is returned by SetContactMatchOptIn and MatchContacts when more than
// maxContactDigestsPerRequest digests are submitted in one call (T-04.1-34). Not present in this
// plan's <artifacts_produced> export list for contactmatch.go, which names only
// ErrContactMatchOptedOut -- added because Task 2's own behavior list ("submitting more than the
// per-request digest cap is rejected") and Task 3's statusForFriendsError mapping ("...and
// over-cap to 400") both structurally require a sentinel to reject and map (Rule 3).
var ErrTooManyContactDigests = errors.New("friends: too many contact digests submitted in one request")

// maxContactDigestsPerRequest bounds how many digests a single SetContactMatchOptIn or
// MatchContacts call may submit (T-04.1-34).
const maxContactDigestsPerRequest = 2000

// ContactMatchSaltEnvVar names the environment variable carrying the fixed, server-side
// application salt applied to every contact digest before it is stored or matched
// (docs/group-events.md §1: "not a plain dictionary of hashed identifiers"). defaultContactMatchSalt
// is used only when that variable is unset -- local development only, per this package's
// documented-default convention (identity.appleBundleIDEnvVar's precedent).
const (
	ContactMatchSaltEnvVar  = "RITHAM_CONTACT_MATCH_SALT"
	defaultContactMatchSalt = "ritham-dev-contact-match-salt-DO-NOT-USE-IN-PRODUCTION"
)

// ContactMatchSaltFromEnv reads ContactMatchSaltEnvVar, falling back to
// defaultContactMatchSalt when unset. Called once at startup (cmd/ritham-service/main.go) and
// passed to New -- never read per call, so a later salt change cannot silently and partially
// change what matches mid-run.
func ContactMatchSaltFromEnv() []byte {
	salt := os.Getenv(ContactMatchSaltEnvVar)
	if salt == "" {
		salt = defaultContactMatchSalt
	}
	return []byte(salt)
}

// saltDigest applies the Service's fixed application salt to a client-submitted digest via HMAC-
// SHA256 (RESEARCH.md's Don't Hand-Roll table: HMAC, not a hand-rolled SHA-256(salt||input)
// concatenation). The same transform is applied identically whether the digest is being stored
// (SetContactMatchOptIn) or queried against (MatchContacts), which is what lets two different
// users' digests of the same underlying identifier compare equal without either side's raw
// identifier, or the client's own pre-salt digest, ever being stored as-is.
func (s *Service) saltDigest(clientDigest []byte) []byte {
	mac := hmac.New(sha256.New, s.contactMatchSalt)
	mac.Write(clientDigest)
	return mac.Sum(nil)
}

// SetContactMatchOptIn records userID's contact-matching opt-in flag and, when optedIn is true,
// replaces their stored digest set with the salted form of identifierDigests -- each digest
// represents one of the user's own identifiers (e.g. their own phone number), submitted already
// hashed by the client (never a raw contact identifier; no column or parameter here accepts one).
// Turning the opt-in off (or simply re-submitting a fresh list while staying opted in) always
// deletes the previously stored digests first, in the same transaction as the flag update -- so
// opting out is not merely a flag flip, and a stale digest from an earlier contact list never
// lingers past its own submission.
func (s *Service) SetContactMatchOptIn(ctx context.Context, userID uuid.UUID, optedIn bool, identifierDigests [][]byte) error {
	if len(identifierDigests) > maxContactDigestsPerRequest {
		return ErrTooManyContactDigests
	}

	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	now := s.now()
	const upsertQuery = `
		INSERT INTO contact_match_optins (user_id, opted_in, updated_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE SET opted_in = $2, updated_at = $3
	`
	if _, err := tx.Exec(ctx, upsertQuery, userID, optedIn, now); err != nil {
		return err
	}

	const deleteQuery = `DELETE FROM contact_match_digests WHERE user_id = $1`
	if _, err := tx.Exec(ctx, deleteQuery, userID); err != nil {
		return err
	}

	if optedIn && len(identifierDigests) > 0 {
		const insertQuery = `
			INSERT INTO contact_match_digests (user_id, digest)
			VALUES ($1, $2)
			ON CONFLICT DO NOTHING
		`
		for _, d := range identifierDigests {
			if _, err := tx.Exec(ctx, insertQuery, userID, s.saltDigest(d)); err != nil {
				return err
			}
		}
	}

	return tx.Commit(ctx)
}

// MatchContacts returns the subset of candidateDigests (each a client-hashed identifier from the
// caller's own device contacts) that match another Ritham user's own stored, opted-in digest.
// Returns ErrContactMatchOptedOut -- before touching contact_match_digests at all -- when the
// caller themselves is not opted in. The underlying query's own JOIN against
// contact_match_optins additionally requires the candidate to be opted in, so a one-sided opt-in
// (in either direction) can never surface a match (T-04.1-32).
func (s *Service) MatchContacts(ctx context.Context, userID uuid.UUID, candidateDigests [][]byte) ([]Friend, error) {
	if len(candidateDigests) > maxContactDigestsPerRequest {
		return nil, ErrTooManyContactDigests
	}

	var callerOptedIn bool
	const optedInQuery = `SELECT opted_in FROM contact_match_optins WHERE user_id = $1`
	err := s.store.Pool().QueryRow(ctx, optedInQuery, userID).Scan(&callerOptedIn)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	if !callerOptedIn {
		return nil, ErrContactMatchOptedOut
	}

	matches := []Friend{}
	if len(candidateDigests) == 0 {
		return matches, nil
	}

	salted := make([][]byte, len(candidateDigests))
	for i, d := range candidateDigests {
		salted[i] = s.saltDigest(d)
	}

	const query = `
		SELECT DISTINCT u.id, u.display_name
		FROM contact_match_digests d
		JOIN contact_match_optins o ON o.user_id = d.user_id AND o.opted_in = true
		JOIN users u ON u.id = d.user_id
		WHERE d.digest = ANY($1) AND d.user_id != $2
	`
	rows, err := s.store.Pool().Query(ctx, query, salted, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var f Friend
		if err := rows.Scan(&f.UserID, &f.DisplayName); err != nil {
			return nil, err
		}
		matches = append(matches, f)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return matches, nil
}
