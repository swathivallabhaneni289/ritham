package plan

import (
	"errors"
	"testing"
)

func TestGenerate_SessionCountMatchesFrequency(t *testing.T) {
	cases := []struct {
		frequency int
		want      int
	}{
		{frequency: 3, want: 3},
		{frequency: 5, want: 5},
		{frequency: 7, want: 7},
	}
	for _, c := range cases {
		got, err := Generate(c.frequency, ExperienceIntermediate, PermissionNone)
		if err != nil {
			t.Fatalf("Generate(%d, ...): unexpected error: %v", c.frequency, err)
		}
		if len(got.Sessions) != c.want {
			t.Errorf("Generate(%d, ...): got %d sessions, want %d", c.frequency, len(got.Sessions), c.want)
		}
	}
}

func TestGenerate_UnsupportedFrequencyReturnsError(t *testing.T) {
	_, err := Generate(4, ExperienceIntermediate, PermissionNone)
	if err == nil {
		t.Fatal("Generate(4, ...): expected a non-nil error for an unsupported frequency, got nil")
	}
	if !errors.Is(err, ErrUnsupportedFrequency) {
		t.Errorf("Generate(4, ...): got error %v, want ErrUnsupportedFrequency", err)
	}
}

func TestGenerate_UnknownExperienceLevelReturnsError(t *testing.T) {
	_, err := Generate(5, ExperienceLevel("expert"), PermissionNone)
	if err == nil {
		t.Fatal("Generate(5, \"expert\", ...): expected a non-nil error for an unknown experience level, got nil")
	}
	if !errors.Is(err, ErrUnknownExperienceLevel) {
		t.Errorf("Generate(5, \"expert\", ...): got error %v, want ErrUnknownExperienceLevel", err)
	}
}

func TestGenerate_UnknownGuidancePermissionReturnsError(t *testing.T) {
	_, err := Generate(5, ExperienceIntermediate, GuidancePermission("full-access"))
	if err == nil {
		t.Fatal("Generate(..., \"full-access\"): expected a non-nil error for an unknown permission, got nil")
	}
	if !errors.Is(err, ErrUnknownGuidancePermission) {
		t.Errorf("Generate(..., \"full-access\"): got error %v, want ErrUnknownGuidancePermission", err)
	}
}

func TestGenerate_LeastRestrictivePermissionCarriesPrescriptions(t *testing.T) {
	got, err := Generate(5, ExperienceIntermediate, PermissionNone)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Sessions) == 0 {
		t.Fatal("expected sessions to be populated at the least restrictive permission")
	}
	for _, s := range got.Sessions {
		if len(s.Exercises) == 0 {
			t.Errorf("session %+v: expected at least one exercise", s)
			continue
		}
		for _, ex := range s.Exercises {
			if ex.Sets <= 0 {
				t.Errorf("exercise %+v: expected a positive set count", ex)
			}
			if ex.RepRange == "" {
				t.Errorf("exercise %+v: expected a non-empty rep range", ex)
			}
		}
	}
}

func TestGenerate_MiddlePermissionCarriesPrescriptionsAndConsultationNote(t *testing.T) {
	got, err := Generate(5, ExperienceIntermediate, PermissionRecommended)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Sessions) == 0 {
		t.Fatal("expected sessions to still be populated at the middle permission")
	}
	for _, s := range got.Sessions {
		if len(s.Exercises) == 0 {
			t.Errorf("session %+v: expected at least one exercise", s)
		}
	}
	if got.GuidanceNote == "" {
		t.Error("expected a professional-consultation guidance note at the middle permission")
	}
}

func TestGenerate_MostRestrictivePermissionCarriesNoNumericPrescriptions(t *testing.T) {
	got, err := Generate(5, ExperienceIntermediate, PermissionRequiredBlocking)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Sessions) != 0 {
		t.Errorf("expected zero sessions at the most restrictive permission, got %d", len(got.Sessions))
	}
	if got.FrequencyPerWeek != 0 {
		t.Errorf("expected zero numeric fields anywhere in the plan at the most restrictive permission, got FrequencyPerWeek=%d", got.FrequencyPerWeek)
	}
	if got.GuidanceNote == "" {
		t.Error("expected a non-empty referral guidance note at the most restrictive permission")
	}
}

func TestGenerate_FocusAreasVaryAcrossTheWeek(t *testing.T) {
	for _, freq := range []int{3, 5, 7} {
		got, err := Generate(freq, ExperienceIntermediate, PermissionNone)
		if err != nil {
			t.Fatalf("Generate(%d, ...): unexpected error: %v", freq, err)
		}
		seen := map[string]bool{}
		for _, s := range got.Sessions {
			seen[s.Focus] = true
		}
		if len(seen) < 2 && freq > 1 {
			t.Errorf("Generate(%d, ...): expected focus areas to vary across the week, got all sessions with %d distinct focus(es)", freq, len(seen))
		}
	}
}

func TestGenerate_ExperienceLevelScalesVolume(t *testing.T) {
	beginner, err := Generate(3, ExperienceBeginner, PermissionNone)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	advanced, err := Generate(3, ExperienceAdvanced, PermissionNone)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(beginner.Sessions) == 0 || len(beginner.Sessions[0].Exercises) == 0 {
		t.Fatal("expected beginner plan to have at least one exercise")
	}
	if len(advanced.Sessions) == 0 || len(advanced.Sessions[0].Exercises) == 0 {
		t.Fatal("expected advanced plan to have at least one exercise")
	}
	beginnerSets := beginner.Sessions[0].Exercises[0].Sets
	advancedSets := advanced.Sessions[0].Exercises[0].Sets
	if beginnerSets >= advancedSets {
		t.Errorf("expected beginner sets (%d) to be fewer than advanced sets (%d)", beginnerSets, advancedSets)
	}
}

func TestGenerate_AllExperienceLevelsAreAccepted(t *testing.T) {
	for _, level := range []ExperienceLevel{ExperienceBeginner, ExperienceIntermediate, ExperienceAdvanced, ExperienceDailyExerciser} {
		if _, err := Generate(3, level, PermissionNone); err != nil {
			t.Errorf("Generate(3, %q, ...): unexpected error: %v", level, err)
		}
	}
}
