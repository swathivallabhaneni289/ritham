package photo

import (
	"bytes"
	"context"
	"os"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// The four environment variables an ObjectStoreConfig is built from, matching plan 04.1-01's
// documented set (RithamService/README.md).
const (
	envObjectStoreEndpoint      = "RITHAM_OBJECT_STORE_ENDPOINT"
	envObjectStoreAccessKey     = "RITHAM_OBJECT_STORE_ACCESS_KEY"
	envObjectStoreSecretKey     = "RITHAM_OBJECT_STORE_SECRET_KEY"
	envObjectStoreBucketPrivate = "RITHAM_OBJECT_STORE_BUCKET_PRIVATE"
	envObjectStoreBucketShared  = "RITHAM_OBJECT_STORE_BUCKET_SHARED"
)

// ObjectStoreConfig configures NewObjectStore. UseSSL defaults to false, matching this project's
// local-dev MinIO (docker-compose.dev.yml) and loopback-only posture -- a real deployment target
// is still an open prerequisite (RithamService/README.md's "Deployment prerequisites").
type ObjectStoreConfig struct {
	Endpoint      string
	AccessKey     string
	SecretKey     string
	UseSSL        bool
	BucketPrivate string
	BucketShared  string
}

// ObjectStoreConfigFromEnv reads the four RITHAM_OBJECT_STORE_* environment variables plan
// 04.1-01 documented, with defaults matching docker-compose.dev.yml's local MinIO service and
// bucket names. It performs no validation and does not connect -- callers pass the result to
// NewObjectStore, which does both.
func ObjectStoreConfigFromEnv() ObjectStoreConfig {
	return ObjectStoreConfig{
		Endpoint:      envOrDefault(envObjectStoreEndpoint, "127.0.0.1:9000"),
		AccessKey:     envOrDefault(envObjectStoreAccessKey, "ritham"),
		SecretKey:     envOrDefault(envObjectStoreSecretKey, "ritham-dev-secret"),
		UseSSL:        false,
		BucketPrivate: envOrDefault(envObjectStoreBucketPrivate, "ritham-photos-private"),
		BucketShared:  envOrDefault(envObjectStoreBucketShared, "ritham-photos-shared"),
	}
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// ObjectStore is a two-tier S3-compatible object store: a private tier for metadata-intact
// originals, and a shared tier for group-visible content. The asymmetry between its two write
// methods -- PutPrivateOriginal takes raw bytes, PutShared takes only a StrippedImage -- is the
// enforcement mechanism behind GROUPEVENTS-03's "no code path may write an image to
// shared/exportable storage without having gone through server-side EXIF stripping first"
// (T-04.1-16): the shared tier's writer cannot compile against a caller that never ran
// StripAndReencode.
type ObjectStore struct {
	client        *minio.Client
	bucketPrivate string
	bucketShared  string
}

// NewObjectStore constructs an ObjectStore against an S3-compatible endpoint (MinIO in local dev,
// per docker-compose.dev.yml; any S3-compatible backend in a real deployment).
func NewObjectStore(cfg ObjectStoreConfig) (*ObjectStore, error) {
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, err
	}
	return &ObjectStore{client: client, bucketPrivate: cfg.BucketPrivate, bucketShared: cfg.BucketShared}, nil
}

// PutPrivateOriginal writes raw bytes, unmodified, to the private (metadata-intact) tier.
//
// This phase's client never calls this method: the metadata-intact original photo stays on the
// user's own device and is never uploaded anywhere (GROUPEVENTS-03). This method exists purely so
// the tier separation is real, compiled code -- not just a documented convention -- and so
// PutShared's `img StrippedImage` constraint below reads as a deliberate asymmetry between two
// real write paths, rather than the only write path that happens to exist.
func (o *ObjectStore) PutPrivateOriginal(ctx context.Context, key string, raw []byte, contentType string) error {
	_, err := o.client.PutObject(ctx, o.bucketPrivate, key, bytes.NewReader(raw), int64(len(raw)),
		minio.PutObjectOptions{ContentType: contentType})
	return err
}

// PutShared writes a StrippedImage to the shared (group-visible) tier. Its image parameter's type
// is StrippedImage, never []byte -- StrippedImage's unexported fields mean the only way to obtain
// a populated value is a real call to StripAndReencode, so no caller in any package, including a
// future one, can hand this method unstripped bytes even by mistake (T-04.1-16).
//
// A zero-value img (never produced by StripAndReencode) returns ErrNotStripped rather than
// writing an empty object.
func (o *ObjectStore) PutShared(ctx context.Context, key string, img StrippedImage) error {
	if img.isZero() {
		return ErrNotStripped
	}
	b := img.Bytes()
	_, err := o.client.PutObject(ctx, o.bucketShared, key, bytes.NewReader(b), int64(len(b)),
		minio.PutObjectOptions{ContentType: img.ContentType()})
	return err
}

// SharedURL returns a presigned, short-TTL URL for reading key from the shared tier. The shared
// bucket itself is never made publicly readable, and no permanently public object URL is ever
// minted -- GROUPEVENTS-04 forbids a generic shareable link, and a permanently public URL would be
// exactly that (T-04.1-20). Every read goes through a freshly minted, time-bounded presigned URL.
func (o *ObjectStore) SharedURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	u, err := o.client.PresignedGetObject(ctx, o.bucketShared, key, ttl, nil)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}
