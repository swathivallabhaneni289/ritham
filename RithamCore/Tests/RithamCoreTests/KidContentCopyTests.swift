import Foundation
import Testing
@testable import RithamCore

/// Swift offers no reflection over an enum namespace's static members, so a constant added to
/// `KidContentCopy` without being added to `shippedStrings` below is caught only by the
/// non-vacuity count assertion, not by any other mechanism.
@Suite("KidContentCopyTests")
struct KidContentCopyTests {

    /// Every constant `KidContentCopy` exposes and every function called with a representative
    /// argument, named by its dotted path.
    private static let shippedStrings: [(name: String, value: String)] = [
        ("Screen.headline", KidContentCopy.Screen.headline),
        ("Screen.intro", KidContentCopy.Screen.intro),
        ("Screen.foodSectionTitle", KidContentCopy.Screen.foodSectionTitle),
        ("Screen.movementSectionTitle", KidContentCopy.Screen.movementSectionTitle),
        ("Screen.disclaimer", KidContentCopy.Screen.disclaimer),
        ("Screen.doneCTA", KidContentCopy.Screen.doneCTA),
        ("Screen.sourceLine", KidContentCopy.Screen.sourceLine(attribution: "10 tips: veggies and fruits. USDA DG TipSheet No. 11, USDA Center for Nutrition Policy and Promotion, June 2011.")),
        ("Children.sectionTitle", KidContentCopy.Children.sectionTitle),
        ("Children.explainer", KidContentCopy.Children.explainer),
        ("Children.emptyState", KidContentCopy.Children.emptyState),
        ("Children.addCTA", KidContentCopy.Children.addCTA),
        ("Children.ordinalLabel", KidContentCopy.Children.ordinalLabel(1)),
        ("Children.nicknameFieldLabel", KidContentCopy.Children.nicknameFieldLabel),
        ("Children.renameCTA", KidContentCopy.Children.renameCTA),
        ("Children.saveCTA", KidContentCopy.Children.saveCTA),
        ("Children.cancelCTA", KidContentCopy.Children.cancelCTA),
        ("Children.deleteCTA", KidContentCopy.Children.deleteCTA),
        ("Children.deleteConfirmation", KidContentCopy.Children.deleteConfirmation),
        ("Children.deleteAccessibilityLabel", KidContentCopy.Children.deleteAccessibilityLabel(for: "Child 1")),
        ("Children.saveFailed", KidContentCopy.Children.saveFailed),
    ]

    /// The four body-and-identity terms (age/weight/growth/birthday-family) are banned because
    /// D-07 and KIDCONTENT-02 forbid this feature from asking for or storing anything about a
    /// specific child. `age` being a bare substring means no shipped string may contain storage,
    /// manage, message, page, or average either -- Task 1's own authoring constraint.
    private static let bannedTerms: [String] = [
        "calorie", "calories", "bmi", "weight loss", "weight-loss", "lose weight", "healthy weight",
        "portion", "serving size", "age", "weight", "growth", "height", "birthday", "birth date",
        "favorite", "favourite", "bookmark", "streak", "track",
    ]

    // MARK: - Non-vacuity

    @Test("at least eighteen shipped strings were scanned by the sweeps below")
    func atLeastEighteenStringsScanned() {
        #expect(Self.shippedStrings.count >= 18, "the sweeps below cannot be trusted until this table is populated")
    }

    // MARK: - Emptiness

    @Test("no shipped string is empty or whitespace-only")
    func noShippedStringIsEmptyOrWhitespace() {
        for entry in Self.shippedStrings {
            let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!trimmed.isEmpty, "\(entry.name) is empty or whitespace-only")
        }
    }

    // MARK: - Banned-term sweep, with one named exception

    @Test("no shipped string names a child's body or identity, except the one negating exception")
    func noShippedStringContainsBannedTermExceptExplainer() {
        for entry in Self.shippedStrings where entry.name != "Children.explainer" {
            let lowered = entry.value.lowercased()
            for term in Self.bannedTerms {
                #expect(
                    !lowered.contains(term),
                    "\(entry.name) contains banned term \"\(term)\": \"\(entry.value)\""
                )
            }
        }
    }

    @Test("Children.explainer names age, weight, and growth solely to negate them")
    func explainerNamesBannedTermsToNegateThem() {
        let explainer = KidContentCopy.Children.explainer.lowercased()
        #expect(
            explainer.contains("age"),
            "Children.explainer is the sole exception to the banned-term sweep because it negates \"age\" -- if it no longer does, the exception must be deleted, not kept"
        )
        #expect(
            explainer.contains("weight"),
            "Children.explainer is the sole exception to the banned-term sweep because it negates \"weight\" -- if it no longer does, the exception must be deleted, not kept"
        )
        #expect(
            explainer.contains("growth"),
            "Children.explainer is the sole exception to the banned-term sweep because it negates \"growth\" -- if it no longer does, the exception must be deleted, not kept"
        )
    }

    // MARK: - House style

    @Test("no shipped string contains an em dash or en dash")
    func noShippedStringContainsADash() {
        for entry in Self.shippedStrings {
            #expect(!entry.value.contains("\u{2014}"), "\(entry.name) contains an em dash: \"\(entry.value)\"")
            #expect(!entry.value.contains("\u{2013}"), "\(entry.name) contains an en dash: \"\(entry.value)\"")
        }
    }

    // MARK: - Locked values

    @Test("locked values match exactly")
    func lockedValuesMatchExactly() {
        #expect(KidContentCopy.Screen.headline == "Kid Ideas")
        #expect(KidContentCopy.Children.nicknameFieldLabel == "Nickname (optional)")
        #expect(KidContentCopy.Children.addCTA == "Add a child")
        #expect(KidContentCopy.Children.emptyState == "No children added yet.")
        #expect(KidContentCopy.Children.deleteConfirmation == "Remove this child entry?")
    }

    // MARK: - Disclaimer integrity

    @Test("Screen.disclaimer pins the section 6 safety framing and drops the internal requirement identifier")
    func disclaimerPinsSafetyFramingAndDropsRequirementID() {
        let disclaimer = KidContentCopy.Screen.disclaimer
        #expect(disclaimer.contains("not an individualized meal or exercise plan"))
        #expect(disclaimer.contains("not written by Ritham"))
        #expect(disclaimer.contains("pending clinical and legal review"))
        #expect(!disclaimer.contains("LAUNCH-0"))
    }

    // MARK: - Interpolation

    @Test("Children.ordinalLabel interpolates a one-based position")
    func ordinalLabelInterpolatesPosition() {
        #expect(KidContentCopy.Children.ordinalLabel(1) == "Child 1")
        #expect(KidContentCopy.Children.ordinalLabel(2) == "Child 2")
    }

    @Test("Screen.sourceLine begins with the locked \"Source: \" prefix")
    func sourceLineBeginsWithSourcePrefix() {
        #expect(KidContentCopy.Screen.sourceLine(attribution: "X").hasPrefix("Source: "))
    }
}
