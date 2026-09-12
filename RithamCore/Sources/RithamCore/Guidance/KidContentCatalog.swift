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

        // Section 2's nine snack ideas, transcribed verbatim, in the source document's own
        // order. Nine of the source's ten tips ship; the tenth ("keep an eye on the size") was
        // excluded in full by docs/kid-content.md section 3 for weight-management/portion-
        // sufficiency framing under D-03 and has no reserved slug here -- do not add a tenth
        // entry to "complete" this block (04.2-RESEARCH.md Pitfall 5).
        KidContentIdea(
            id: "food.save-time-by-slicing-veggies",
            category: .food,
            title: "Save time by slicing veggies",
            body: "Store sliced vegetables in the refrigerator and serve with dips like hummus or low-fat dressing. Top half a whole-wheat English muffin with spaghetti sauce, chopped vegetables, and low-fat shredded mozzarella and melt in the microwave.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.mix-it-up",
            category: .food,
            title: "Mix it up",
            body: "For older school-age kids, mix dried fruit, unsalted nuts, and popcorn in a snack-size bag for a quick trail mix. Blend plain fat-free or low-fat yogurt with 100% fruit juice and frozen peaches for a tasty smoothie.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.grab-a-glass-of-milk",
            category: .food,
            title: "Grab a glass of milk",
            body: "A cup of low-fat or fat-free milk or milk alternative (soy milk) is an easy way to drink a healthy snack.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.go-for-great-whole-grains",
            category: .food,
            title: "Go for great whole grains",
            body: "Offer whole-wheat breads, popcorn, and whole-oat cereals that are high in fiber and low in added sugars, saturated fat, and sodium. Limit refined-grain products such as snack bars, cakes, and sweetened cereals.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.nibble-on-lean-protein",
            category: .food,
            title: "Nibble on lean protein",
            body: "Choose lean protein foods such as low-sodium deli meats, unsalted nuts, or eggs. Wrap sliced, low-sodium deli turkey or ham around an apple wedge. Store unsalted nuts in the pantry or peeled, hard-cooked (boiled) eggs in the refrigerator for kids to enjoy any time.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        // Trimmed per docs/kid-content.md section 3: the source's own serve-amount/portion-
        // sufficiency clause is removed from each of the next three tips; the rest of each tip's
        // verbatim text is kept and still reads sensibly.
        KidContentIdea(
            id: "food.fruits-are-quick-and-easy",
            category: .food,
            title: "Fruits are quick and easy",
            body: "Fresh, frozen, dried, or canned fruits can be easy 'grab-and-go' options that need little preparation. Offer whole fruit.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.consider-convenience",
            category: .food,
            title: "Consider convenience",
            body: "A single-serving container of low-fat or fat-free yogurt or individually wrapped string cheese...",
            citation: KidContentCatalog.snackTipsCitation
        ),
        KidContentIdea(
            id: "food.swap-out-the-sugar",
            category: .food,
            title: "Swap out the sugar",
            body: "Keep healthier foods handy so kids avoid cookies, pastries, or candies between meals. Add seltzer water to 100% fruit juice instead of offering soda.",
            citation: KidContentCatalog.snackTipsCitation
        ),
        // Not trimmed -- docs/kid-content.md section 3 explicitly carves recipe-batch
        // ingredient ratios out of the exclusion rule, since they adjust a dish being prepared
        // rather than telling a child how much of the finished food to eat.
        KidContentIdea(
            id: "food.prepare-homemade-goodies",
            category: .food,
            title: "Prepare homemade goodies",
            body: "For homemade sweets, add dried fruits like apricots or raisins and reduce the amount of sugar. Adjust recipes that include fats like butter or shortening by using unsweetened applesauce or prune puree for half the amount of fat.",
            citation: KidContentCatalog.snackTipsCitation
        ),

        // Section 4's eight movement ideas. Titles 1-4 below are Ritham's own short labels --
        // section 4 prints those four quotes under descriptive headings, not under source-
        // authored tip titles, so a label had to be supplied. Titles 5-8 are CDC's own activity-
        // category names. Joining CDC's bulleted example activities into period-separated
        // sentences, and sentence-capitalising the push-up example, are presentation transforms
        // of the same class as the dash rewrite this file's sibling guidance catalogs' headers
        // describe -- no word is added, removed, or reordered.
        KidContentIdea(
            id: "movement.minutes-every-day",
            category: .movement,
            title: "Minutes every day",
            body: "Children and adolescents (age 6-17) need at least 60 minutes of physical activity every day.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.weekly-mix",
            category: .movement,
            title: "The weekly mix",
            body: "Children and adolescents need a mix of aerobic, muscle, and bone-strengthening activities each week. Children and adolescents need moderate- or vigorous-intensity aerobic physical activity every day. They also need muscle- and bone-strengthening activity at least 3 days each week.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.vigorous-days",
            category: .movement,
            title: "Vigorous days",
            body: "Most of the 60 minutes or more should be either moderate- or vigorous-intensity aerobic physical activity, and should include vigorous-intensity physical activity on at least 3 days a week.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.intensity-check",
            category: .movement,
            title: "Telling moderate from vigorous",
            body: "In general, at moderate intensity, children can talk but not sing during the physical activity. At vigorous intensity, children can only say a few words without pausing for a breath.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.aerobic-moderate",
            category: .movement,
            title: "Moderate-intensity aerobic activity",
            body: "Brisk walking. Bicycle riding (mostly on flat surfaces without many hills). Active recreation, such as hiking.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.aerobic-vigorous",
            category: .movement,
            title: "Vigorous-intensity aerobic activity",
            body: "Running. Jumping rope. Sports such as soccer, basketball, swimming, and tennis.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.muscle-strengthening",
            category: .movement,
            title: "Muscle-strengthening activity",
            body: "Climbing on playground equipment. Resistance exercises using body weight. Doing push-ups.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
        KidContentIdea(
            id: "movement.bone-strengthening",
            category: .movement,
            title: "Bone-strengthening activity",
            body: "Hopping, skipping, jumping. Jumping rope. Running.",
            citation: KidContentCatalog.physicalActivityCitation
        ),
    ]

    /// Filters `ideas` by category -- a filter and nothing else, no permission check, no tag
    /// parameter (04.2-RESEARCH.md Pitfall 4).
    public static func ideas(in category: KidContentCategory) -> [KidContentIdea] {
        ideas.filter { $0.category == category }
    }
}
