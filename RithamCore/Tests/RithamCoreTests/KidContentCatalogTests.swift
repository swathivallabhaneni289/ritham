import Foundation
import Testing
@testable import RithamCore

// Deliberate non-test: docs/kid-content.md section 3's broader rule (exclude any clause naming a
// measured serve amount of a consumed food) is NOT asserted here, because two strings the
// document itself ships would fail it -- food.grab-a-glass-of-milk's "A cup of low-fat..." milk
// quantity and food.prepare-homemade-goodies' recipe-ratio phrasing, the latter explicitly carved
// out by section 3 itself. Resolving that tension is a Phase 5 clinical-review judgment
// (04.2-RESEARCH.md Assumptions Log A2 and Open Question 2), not this phase's to settle in code.

@Suite("KidContentCatalogTests")
struct KidContentCatalogTests {

    /// The three citation constants, named for the sweep below.
    private static let citationEntries: [(name: String, citation: KidContentCitation)] = [
        ("veggiesAndFruitsCitation", KidContentCatalog.veggiesAndFruitsCitation),
        ("snackTipsCitation", KidContentCatalog.snackTipsCitation),
        ("physicalActivityCitation", KidContentCatalog.physicalActivityCitation),
    ]

    /// Every string the catalog exposes: each idea's title and body (named by slug plus field),
    /// the two source-preamble intros, and the four string fields of each of the three citation
    /// constants. Built by mapping over `KidContentCatalog.ideas` rather than hand-listing 27
    /// entries, so a future idea is swept automatically.
    private static let scannedStrings: [(name: String, value: String)] = {
        var entries: [(name: String, value: String)] = []
        for idea in KidContentCatalog.ideas {
            entries.append(("\(idea.id).title", idea.title))
            entries.append(("\(idea.id).body", idea.body))
        }
        entries.append(("veggiesAndFruitsIntro", KidContentCatalog.veggiesAndFruitsIntro))
        entries.append(("snackTipsIntro", KidContentCatalog.snackTipsIntro))
        for (name, citation) in citationEntries {
            entries.append(("\(name).documentTitle", citation.documentTitle))
            entries.append(("\(name).documentIdentifier", citation.documentIdentifier))
            entries.append(("\(name).publishingBody", citation.publishingBody))
            entries.append(("\(name).publicationDate", citation.publicationDate))
        }
        return entries
    }()

    /// Phrases, not bare stems -- a bare-stem sweep would false-positive on real shipped USDA/CDC
    /// text this catalog must keep: "weight" appears inside movement.muscle-strengthening's CDC
    /// resistance-exercise example ("Resistance exercises using body weight"); "serving" appears
    /// inside food.consider-convenience's yogurt-container snack tip ("A single-serving
    /// container..."); "limit", "cup", "half", "amount", and "favorite" all appear in legitimately
    /// shipped USDA tip text (food.go-for-great-whole-grains' "Limit refined-grain products",
    /// food.grab-a-glass-of-milk's "A cup of low-fat...", food.prepare-homemade-goodies' "half the
    /// amount of fat", food.personalized-pizzas' "their own favorites"); and a bare percent sign
    /// appears in food.mix-it-up and food.swap-out-the-sugar as a "100% fruit juice" purity
    /// descriptor. None of those six bare stems may be added to this list.
    private static let bannedPhrases: [String] = [
        "calorie",
        "calories",
        "kcal",
        "bmi",
        "body mass index",
        "weight loss",
        "weight-loss",
        "lose weight",
        "healthy weight",
        "weight management",
        "portion",
        "serving size",
        "serving sizes",
        "macro",
        "\u{00BD}",
    ]

    /// The tip `docs/kid-content.md` section 3 excludes in full ("keep an eye on the size"),
    /// verbatim: "Snacks shouldn't replace a meal, so look for ways to help your kids understand
    /// how much is enough. Store snack-size bags in the cupboard and use them to control serving
    /// sizes." A regression here means that tip was reintroduced.
    private static let pitfall5ExcludedPhrases: [String] = [
        "how much is enough",
        "control serving sizes",
        "keep an eye on the size",
    ]

    // MARK: - Non-vacuity

    @Test("at least sixty strings were scanned by the sweep, so it cannot pass by scanning nothing")
    func atLeastSixtyStringsScanned() {
        #expect(Self.scannedStrings.count >= 60)
    }

    // MARK: - Exact counts

    @Test("the catalog holds exactly 27 ideas, split 19 food / 8 movement, over exactly two categories")
    func exactCounts() {
        #expect(KidContentCatalog.ideas.count == 27)
        #expect(KidContentCatalog.ideas(in: .food).count == 19)
        #expect(KidContentCatalog.ideas(in: .movement).count == 8)
        #expect(KidContentCategory.allCases.count == 2)
    }

    // MARK: - Identity

    @Test("every idea's slug is unique")
    func slugsAreUnique() {
        let ids = KidContentCatalog.ideas.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("every idea's slug prefix matches its own category")
    func slugPrefixMatchesCategory() {
        for idea in KidContentCatalog.ideas {
            switch idea.category {
            case .food:
                #expect(idea.id.hasPrefix("food."), "\(idea.id) is .food but its slug doesn't start with food.")
            case .movement:
                #expect(idea.id.hasPrefix("movement."), "\(idea.id) is .movement but its slug doesn't start with movement.")
            }
        }
    }

    // MARK: - Shape

    @Test("no scanned string is empty or whitespace-only")
    func noScannedStringIsEmptyOrWhitespace() {
        for entry in Self.scannedStrings {
            let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!trimmed.isEmpty, "\(entry.name) is empty or whitespace-only")
        }
    }

    // MARK: - Prohibited content (D-03)

    @Test("no scanned string contains a calorie, macro, portion, serving-size, BMI, or weight-management phrase")
    func noScannedStringContainsProhibitedPhrase() {
        for entry in Self.scannedStrings {
            let lowered = entry.value.lowercased()
            for phrase in Self.bannedPhrases {
                #expect(
                    !lowered.contains(phrase.lowercased()),
                    "\(entry.name) contains prohibited phrase \"\(phrase)\": \"\(entry.value)\""
                )
            }
        }
    }

    // MARK: - Pitfall 5 regression gate

    @Test("no scanned string reintroduces the tip docs/kid-content.md section 3 excluded in full")
    func noScannedStringReintroducesTheExcludedTenthSnackTip() {
        for entry in Self.scannedStrings {
            let lowered = entry.value.lowercased()
            for phrase in Self.pitfall5ExcludedPhrases {
                #expect(
                    !lowered.contains(phrase),
                    """
                    \(entry.name) contains "\(phrase)": the tip docs/kid-content.md section 3 \
                    excluded in full has been reintroduced. A revision must transcribe from that \
                    document, not from the source PDF.
                    """
                )
            }
        }
    }

    // MARK: - House style

    @Test("no scanned string contains an em dash or en dash")
    func noScannedStringContainsADash() {
        for entry in Self.scannedStrings {
            #expect(!entry.value.contains("\u{2014}"), "\(entry.name) contains an em dash: \"\(entry.value)\"")
            #expect(!entry.value.contains("\u{2013}"), "\(entry.name) contains an en dash: \"\(entry.value)\"")
        }
    }

    // MARK: - Verbatim spot checks

    @Test("food.bugs-on-a-log's body is verbatim from DG TipSheet No. 11")
    func bugsOnALogIsVerbatim() {
        let idea = KidContentCatalog.ideas.first { $0.id == "food.bugs-on-a-log" }
        #expect(idea?.body == "Use celery, cucumber, or carrot sticks as the log and add peanut butter. Top with dried fruit such as raisins, cranberries, or cherries, depending on what bugs you want.")
    }

    @Test("food.grab-a-glass-of-milk's body is verbatim from DG TipSheet No. 24")
    func grabAGlassOfMilkIsVerbatim() {
        let idea = KidContentCatalog.ideas.first { $0.id == "food.grab-a-glass-of-milk" }
        #expect(idea?.body == "A cup of low-fat or fat-free milk or milk alternative (soy milk) is an easy way to drink a healthy snack.")
    }

    @Test("movement.intensity-check's body is verbatim from the CDC intensity guidance")
    func intensityCheckIsVerbatim() {
        let idea = KidContentCatalog.ideas.first { $0.id == "movement.intensity-check" }
        #expect(idea?.body == "In general, at moderate intensity, children can talk but not sing during the physical activity. At vigorous intensity, children can only say a few words without pausing for a breath.")
    }

    // MARK: - Citation integrity

    @Test("every food idea cites one of the two USDA citations, and every movement idea cites the CDC citation")
    func citationsMatchCategory() {
        for idea in KidContentCatalog.ideas {
            switch idea.category {
            case .food:
                #expect(
                    idea.citation == KidContentCatalog.veggiesAndFruitsCitation
                        || idea.citation == KidContentCatalog.snackTipsCitation,
                    "\(idea.id) does not cite a USDA citation"
                )
            case .movement:
                #expect(
                    idea.citation == KidContentCatalog.physicalActivityCitation,
                    "\(idea.id) does not cite the CDC citation"
                )
            }
        }
    }

    @Test("KidContentCitation.attribution assembles the expected literal for veggiesAndFruitsCitation")
    func attributionAssemblesExpectedLiteral() {
        #expect(
            KidContentCatalog.veggiesAndFruitsCitation.attribution
                == "10 tips Nutrition Education Series: veggies and fruits. DG TipSheet No. 11, USDA Center for Nutrition Policy and Promotion, June 2011."
        )
    }
}
