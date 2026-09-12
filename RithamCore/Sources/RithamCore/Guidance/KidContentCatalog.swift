// Every string in this file is transcribed verbatim from `docs/kid-content.md` -- that document,
// not the original USDA/CDC PDFs, is the sole source for any future revision of this catalog.
// `docs/kid-content.md` section 3 already applied a content-exclusion rule (dropping/trimming
// serve-amount and weight-management framing) that the original PDFs do not carry; going back to
// a PDF directly would silently reintroduce content this catalog must never ship. There is no
// arithmetic anywhere in this file, so no figure it exposes can ever become a number computed
// from a specific child's data. Per D-03 (extending `HEALTH-04`'s `Under 18 (Minor)` prohibition
// to the actual under-13 child), this file carries no calorie, macro, portion, serving-size, BMI,
// or weight-management content of any kind. Per D-06 the scope is preteens only and
// `KidContentCategory` has exactly two cases -- no toddler/preschool/school-age band exists here
// or should ever be added speculatively "for future use." Per 04.2-RESEARCH.md Pitfall 4 this
// catalog is deliberately NOT gated: it must never call the shared per-tag permission-check
// function this directory's other clinical guidance catalogs route through, must never take a
// condition tag as a parameter anywhere, and must never grow a permission-domain case of its own,
// because this content carries no condition-tag dimension at all -- it is general, non-
// personalized education a parent opts into by recording a preteen exists. This content ships
// pending Phase 5's LAUNCH-02/LAUNCH-03 clinical and legal review, the same posture as this
// codebase's Nutrition and Workout Guidance Catalogs.

/// Exactly two content categories -- food and movement -- with no age-band case (D-06). This is
/// a flat namespace split, never a permission or gating dimension.
public enum KidContentCategory: String, Sendable, Equatable, CaseIterable {
    case food
    case movement
}

/// A citable source attribution, one per idea. Mirrors the Nutrition Guidance Catalog's
/// `ReferenceFigure` label/value/publishingBody shape but for a transcribed idea rather than a
/// numeric figure.
public struct KidContentCitation: Sendable, Equatable {
    public let documentTitle: String
    public let documentIdentifier: String
    public let publishingBody: String
    public let publicationDate: String

    public init(documentTitle: String, documentIdentifier: String, publishingBody: String, publicationDate: String) {
        self.documentTitle = documentTitle
        self.documentIdentifier = documentIdentifier
        self.publishingBody = publishingBody
        self.publicationDate = publicationDate
    }

    /// Assembled display attribution: "{documentTitle}. {documentIdentifier}, {publishingBody}, {publicationDate}."
    public var attribution: String {
        "\(documentTitle). \(documentIdentifier), \(publishingBody), \(publicationDate)."
    }
}

/// One browsable idea (KIDCONTENT-01). `body` is the verbatim transcribed tip text -- never
/// paraphrased, never containing a calorie/macro/portion/BMI figure (D-03).
public struct KidContentIdea: Sendable, Equatable, Identifiable {
    public let id: String
    public let category: KidContentCategory
    public let title: String
    public let body: String
    public let citation: KidContentCitation

    public init(id: String, category: KidContentCategory, title: String, body: String, citation: KidContentCitation) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.citation = citation
    }
}

/// Namespace holding the citations, source preambles, and the full set of transcribed ideas.
/// Never instantiated.
public enum KidContentCatalog {

    // MARK: - Citations

    public static let veggiesAndFruitsCitation = KidContentCitation(
        documentTitle: "10 tips Nutrition Education Series: veggies and fruits",
        documentIdentifier: "DG TipSheet No. 11",
        publishingBody: "USDA Center for Nutrition Policy and Promotion",
        publicationDate: "June 2011"
    )

    public static let snackTipsCitation = KidContentCitation(
        documentTitle: "10 tips Nutrition Education Series: snack tips for parents",
        documentIdentifier: "DG TipSheet No. 24",
        publishingBody: "USDA Center for Nutrition Policy and Promotion",
        publicationDate: "March 2013"
    )

    public static let physicalActivityCitation = KidContentCitation(
        documentTitle: "Physical Activity Guidelines for Americans, 2nd edition",
        documentIdentifier: "CDC Physical Activity Basics: What Counts for Children and Teens",
        publishingBody: "Centers for Disease Control and Prevention / U.S. Department of Health and Human Services",
        publicationDate: "2018"
    )

    // MARK: - Source preambles

    /// Section 1 preamble, verbatim, covered by `veggiesAndFruitsCitation`.
    public static let veggiesAndFruitsIntro = "Encourage children to eat vegetables and fruits by making it fun. Provide healthy ingredients and let kids help with preparation, based on their age and skills. Kids may try foods they avoided in the past if they helped make them."

    /// Section 2 preamble as trimmed in `docs/kid-content.md` -- the document's own third and
    /// fourth source sentences only; its first two source sentences were already dropped under
    /// section 3's content-exclusion rule and must not be restored here. Covered by
    /// `snackTipsCitation`. The ChooseMyPlate.gov domain named inside this verbatim sentence is
    /// shipped as published and is a Phase 5 re-verification item, not something to silently
    /// modernise here -- D-01 forbids editing source wording.
    public static let snackTipsIntro = "Let older kids make their own snacks by keeping healthy foods in the kitchen. Visit ChooseMyPlate.gov to help you and your kids select a satisfying snack."

    // MARK: - Ideas

    /// Section 1's ten veggies-and-fruits ideas, transcribed verbatim, in the source document's
    /// own order (Task 2 appends the section 2 snack ideas and the section 4 movement ideas).
    public static let ideas: [KidContentIdea] = [
        KidContentIdea(
            id: "food.smoothie-creations",
            category: .food,
            title: "Smoothie creations",
            body: "Blend fat-free or low-fat yogurt or milk with fruit pieces and crushed ice. Use fresh, frozen, canned, and even overripe fruits. Try bananas, berries, peaches, and/or pineapple. If you freeze the fruit first, you can even skip the ice.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.delicious-dippers",
            category: .food,
            title: "Delicious dippers",
            body: "Kids love to dip their foods. Whip up a quick dip for veggies with yogurt and seasonings such as herbs or garlic. Serve with raw vegetables like broccoli, carrots, or cauliflower. Fruit chunks go great with a yogurt and cinnamon or vanilla dip.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.caterpillar-kabobs",
            category: .food,
            title: "Caterpillar kabobs",
            body: "Assemble chunks of melon, apple, orange, and pear on skewers for a fruity kabob. For a raw veggie version, use vegetables like zucchini, cucumber, squash, sweet peppers, or tomatoes.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.personalized-pizzas",
            category: .food,
            title: "Personalized pizzas",
            body: "Set up a pizza-making station in the kitchen. Use whole-wheat English muffins, bagels, or pita bread as the crust. Have tomato sauce, low-fat cheese, and cut-up vegetables or fruits for toppings. Let kids choose their own favorites. Then pop the pizzas into the oven to warm.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.fruity-peanut-butterfly",
            category: .food,
            title: "Fruity peanut butterfly",
            body: "Start with carrot sticks or celery for the body. Attach wings made of thinly sliced apples with peanut butter and decorate with halved grapes or dried fruit.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.frosty-fruits",
            category: .food,
            title: "Frosty fruits",
            body: "Frozen treats are bound to be popular in the warm months. Just put fresh fruits such as melon chunks in the freezer (rinse first). Make 'popsicles' by inserting sticks into peeled bananas and freezing.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.bugs-on-a-log",
            category: .food,
            title: "Bugs on a log",
            body: "Use celery, cucumber, or carrot sticks as the log and add peanut butter. Top with dried fruit such as raisins, cranberries, or cherries, depending on what bugs you want.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.homemade-trail-mix",
            category: .food,
            title: "Homemade trail mix",
            body: "Skip the pre-made trail mix and make your own. Use your favorite nuts and dried fruits, such as unsalted peanuts, cashews, walnuts, or sunflower seeds mixed with dried apples, pineapple, cherries, apricots, or raisins. Add whole-grain cereals to the mix, too.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.potato-person",
            category: .food,
            title: "Potato person",
            body: "Decorate half a baked potato. Use sliced cherry tomatoes, peas, and low-fat cheese on the potato to make a funny face.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
        KidContentIdea(
            id: "food.put-kids-in-charge",
            category: .food,
            title: "Put kids in charge",
            body: "Ask your child to name new veggie or fruit creations. Let them arrange raw veggies or fruits into a fun shape or design.",
            citation: KidContentCatalog.veggiesAndFruitsCitation
        ),
    ]

    /// Filters `ideas` by category -- a filter and nothing else, no permission check, no tag
    /// parameter (04.2-RESEARCH.md Pitfall 4).
    public static func ideas(in category: KidContentCategory) -> [KidContentIdea] {
        ideas.filter { $0.category == category }
    }
}
