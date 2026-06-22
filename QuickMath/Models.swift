import Foundation
import SwiftData

// MARK: - SwiftData Models

/// A hand-curated daily conversation prompt.
@Model
final class DailyPrompt {
    var id: UUID
    var dateKey: String   // "YYYY-MM-DD" — the calendar date this prompt is assigned to
    var text: String
    var theme: String     // "deep" | "playful" | "gratitude"

    init(id: UUID = UUID(), dateKey: String, text: String, theme: String = "deep") {
        self.id = id
        self.dateKey = dateKey
        self.text = text
        self.theme = theme
    }
}

/// A saved answer/exchange the user wrote for a specific prompt and person.
@Model
final class SavedAnswer {
    var id: UUID
    var promptID: UUID
    var personLabel: String
    var response: String
    var date: Date

    init(id: UUID = UUID(), promptID: UUID, personLabel: String, response: String, date: Date = .now) {
        self.id = id
        self.promptID = promptID
        self.personLabel = personLabel
        self.response = response
        self.date = date
    }
}

/// A prompt the user has starred/favourited.
@Model
final class FavoritePrompt {
    var id: UUID
    var promptID: UUID
    var savedAt: Date

    init(id: UUID = UUID(), promptID: UUID, savedAt: Date = .now) {
        self.id = id
        self.promptID = promptID
        self.savedAt = savedAt
    }
}

// MARK: - Bundled corpus

/// A year-plus corpus of curated prompts bundled at compile time.
struct PromptEntry: Codable {
    let text: String
    let theme: String
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    // Published state
    @Published private(set) var todayPrompt: DailyPrompt? = nil
    @Published private(set) var allPrompts: [DailyPrompt] = []
    @Published private(set) var savedAnswers: [SavedAnswer] = []
    @Published private(set) var favorites: [FavoritePrompt] = []
    @Published private(set) var bonusPrompts: [DailyPrompt] = []  // 3 daily extras (Pro)

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DailyPrompt.self, SavedAnswer.self, FavoritePrompt.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    func reload() {
        seedIfNeeded()
        let ctx = container.mainContext

        let promptDesc = FetchDescriptor<DailyPrompt>(sortBy: [SortDescriptor(\.dateKey, order: .reverse)])
        allPrompts = (try? ctx.fetch(promptDesc)) ?? []

        let todayKey = Self.todayKey()
        todayPrompt = allPrompts.first(where: { $0.dateKey == todayKey })

        let answerDesc = FetchDescriptor<SavedAnswer>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        savedAnswers = (try? ctx.fetch(answerDesc)) ?? []

        let favDesc = FetchDescriptor<FavoritePrompt>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        favorites = (try? ctx.fetch(favDesc)) ?? []

        buildBonusPrompts()
    }

    func refresh() { reload() }

    // MARK: Today key helper
    static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    // MARK: Seed the corpus into SwiftData on first launch
    private func seedIfNeeded() {
        let ctx = container.mainContext
        let desc = FetchDescriptor<DailyPrompt>()
        let count = (try? ctx.fetchCount(desc)) ?? 0
        guard count == 0 else { return }

        // 400-day corpus: date-stamped from today backwards so today always has a question
        let corpus = Self.corpus
        let cal = Calendar.current
        let base = Date()
        for (offset, entry) in corpus.enumerated() {
            let date = cal.date(byAdding: .day, value: -offset, to: base) ?? base
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            let key = fmt.string(from: date)
            let prompt = DailyPrompt(dateKey: key, text: entry.text, theme: entry.theme)
            ctx.insert(prompt)
        }
        try? ctx.save()
    }

    // MARK: Build 3 bonus prompts from corpus entries not shown today (Pro)
    private func buildBonusPrompts() {
        let todayKey = Self.todayKey()
        let others = allPrompts.filter { $0.dateKey != todayKey }
        bonusPrompts = Array(others.shuffled().prefix(3))
    }

    // MARK: Save an answer
    func saveAnswer(promptID: UUID, personLabel: String, response: String) {
        let ctx = container.mainContext
        let answer = SavedAnswer(promptID: promptID, personLabel: personLabel, response: response)
        ctx.insert(answer)
        try? ctx.save()
        reload()
    }

    // MARK: Toggle favourite
    func toggleFavorite(promptID: UUID) {
        let ctx = container.mainContext
        if let existing = favorites.first(where: { $0.promptID == promptID }) {
            ctx.delete(existing)
        } else {
            ctx.insert(FavoritePrompt(promptID: promptID))
        }
        try? ctx.save()
        reload()
    }

    func isFavorite(promptID: UUID) -> Bool {
        favorites.contains(where: { $0.promptID == promptID })
    }

    func answers(for promptID: UUID) -> [SavedAnswer] {
        savedAnswers.filter { $0.promptID == promptID }
    }

    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: DailyPrompt.self)
        try? ctx.delete(model: SavedAnswer.self)
        try? ctx.delete(model: FavoritePrompt.self)
        try? ctx.save()
        reload()
    }

    // MARK: Corpus (400 hand-curated prompts)
    static let corpus: [PromptEntry] = [
        // Deep
        PromptEntry(text: "What's something you've changed your mind about in the last year?", theme: "deep"),
        PromptEntry(text: "If you could relive one day from your past exactly as it was, which would you choose?", theme: "deep"),
        PromptEntry(text: "What does 'home' mean to you right now?", theme: "deep"),
        PromptEntry(text: "What's a fear you've never told anyone about?", theme: "deep"),
        PromptEntry(text: "What do you think is your biggest blind spot?", theme: "deep"),
        PromptEntry(text: "What's a belief you hold that most people in your life would disagree with?", theme: "deep"),
        PromptEntry(text: "What part of your childhood shaped you the most?", theme: "deep"),
        PromptEntry(text: "What's something you've forgiven someone for but haven't fully let go of?", theme: "deep"),
        PromptEntry(text: "What would you do differently if you knew no one would judge you?", theme: "deep"),
        PromptEntry(text: "What's a moment you're proudest of that almost no one knows about?", theme: "deep"),
        PromptEntry(text: "What does success look like to you at 80?", theme: "deep"),
        PromptEntry(text: "What's something you wish you had said to someone but never did?", theme: "deep"),
        PromptEntry(text: "How do you want people to describe you when you're not in the room?", theme: "deep"),
        PromptEntry(text: "What's the hardest thing you've ever had to accept about yourself?", theme: "deep"),
        PromptEntry(text: "What relationship has taught you the most — and what did it teach you?", theme: "deep"),
        PromptEntry(text: "If your younger self met you today, what would surprise them the most?", theme: "deep"),
        PromptEntry(text: "What's a dream you've quietly let go of, and are you at peace with that?", theme: "deep"),
        PromptEntry(text: "When do you feel most like yourself?", theme: "deep"),
        PromptEntry(text: "What's a lie you used to tell yourself?", theme: "deep"),
        PromptEntry(text: "What's the nicest thing a stranger has ever done for you?", theme: "deep"),
        // Playful
        PromptEntry(text: "If your life were a movie, what genre would it be right now?", theme: "playful"),
        PromptEntry(text: "What's the most embarrassing song on your most-played list?", theme: "playful"),
        PromptEntry(text: "If you had to eat only three foods for a month, what would they be?", theme: "playful"),
        PromptEntry(text: "What's the weirdest thing you believed as a kid?", theme: "playful"),
        PromptEntry(text: "If you could swap lives with any fictional character for a week, who?", theme: "playful"),
        PromptEntry(text: "What's a talent you have that would surprise most people?", theme: "playful"),
        PromptEntry(text: "What's the strangest thing you've ever Googled?", theme: "playful"),
        PromptEntry(text: "If you had to rename yourself, what name would you pick?", theme: "playful"),
        PromptEntry(text: "What's a childhood show or book you're a little embarrassed to still love?", theme: "playful"),
        PromptEntry(text: "What's your most irrational pet peeve?", theme: "playful"),
        PromptEntry(text: "If you could instantly master one skill, what would it be?", theme: "playful"),
        PromptEntry(text: "What's the most spontaneous thing you've ever done?", theme: "playful"),
        PromptEntry(text: "If you could have a conversation with any animal, which would you pick?", theme: "playful"),
        PromptEntry(text: "What's a completely useless fact you know by heart?", theme: "playful"),
        PromptEntry(text: "What's the last thing you did that made you laugh until it hurt?", theme: "playful"),
        PromptEntry(text: "If you had to live in any decade from the past, which would you choose?", theme: "playful"),
        PromptEntry(text: "What's a habit you have that you'd never admit in a job interview?", theme: "playful"),
        PromptEntry(text: "What's your go-to karaoke song (even if you'd never actually sing it)?", theme: "playful"),
        PromptEntry(text: "If you could add one rule to the world, what would it be?", theme: "playful"),
        PromptEntry(text: "What's the worst advice you've ever followed?", theme: "playful"),
        // Gratitude
        PromptEntry(text: "What's something small that made today a little better?", theme: "gratitude"),
        PromptEntry(text: "Who's someone you haven't thanked enough, and why?", theme: "gratitude"),
        PromptEntry(text: "What's a place that always lifts your mood just by being there?", theme: "gratitude"),
        PromptEntry(text: "What's a simple pleasure you'd miss more than anything if it disappeared?", theme: "gratitude"),
        PromptEntry(text: "What's something your body does well that you usually take for granted?", theme: "gratitude"),
        PromptEntry(text: "What's a skill or strength you've developed that you used to doubt you had?", theme: "gratitude"),
        PromptEntry(text: "What's the best gift you've ever received — and why did it mean so much?", theme: "gratitude"),
        PromptEntry(text: "What's something in your everyday routine that quietly makes your life better?", theme: "gratitude"),
        PromptEntry(text: "What's a challenge from your past that you're now genuinely grateful for?", theme: "gratitude"),
        PromptEntry(text: "What's something you own that you'd be lost without, that cost almost nothing?", theme: "gratitude"),
        // More deep
        PromptEntry(text: "What do you need more of in your life right now?", theme: "deep"),
        PromptEntry(text: "What's a boundary you've set that changed everything?", theme: "deep"),
        PromptEntry(text: "What's the most important lesson a failure taught you?", theme: "deep"),
        PromptEntry(text: "What do you think people misunderstand about you most?", theme: "deep"),
        PromptEntry(text: "What's a risk you wish you'd taken sooner?", theme: "deep"),
        PromptEntry(text: "What's something you still feel guilty about even though you've moved on?", theme: "deep"),
        PromptEntry(text: "What does love look like in action, to you?", theme: "deep"),
        PromptEntry(text: "What's the most important thing you've learned about yourself in the last five years?", theme: "deep"),
        PromptEntry(text: "What would you attempt if failure had no consequences?", theme: "deep"),
        PromptEntry(text: "What's a habit that's changed your life — for better or worse?", theme: "deep"),
        // More playful
        PromptEntry(text: "What's the most creative excuse you've ever given for being late?", theme: "playful"),
        PromptEntry(text: "What's a movie or show you've seen more times than you'd like to admit?", theme: "playful"),
        PromptEntry(text: "What's the last app you downloaded but barely used?", theme: "playful"),
        PromptEntry(text: "What food combination do you love that others find disgusting?", theme: "playful"),
        PromptEntry(text: "If you could teleport anywhere right now for 24 hours, where would you go?", theme: "playful"),
        PromptEntry(text: "What's the funniest misunderstanding you've had with someone?", theme: "playful"),
        PromptEntry(text: "If you could only listen to one album for a year, what would it be?", theme: "playful"),
        PromptEntry(text: "What's your most controversial food opinion?", theme: "playful"),
        PromptEntry(text: "What's the weirdest place you've fallen asleep?", theme: "playful"),
        PromptEntry(text: "If you had a theme song that played whenever you walked into a room, what would it be?", theme: "playful"),
        // More gratitude
        PromptEntry(text: "What's a conversation that changed how you see the world?", theme: "gratitude"),
        PromptEntry(text: "What's something you've made with your own hands that you're proud of?", theme: "gratitude"),
        PromptEntry(text: "What's an opportunity you almost passed up that turned out to be life-changing?", theme: "gratitude"),
        PromptEntry(text: "What's a tradition — big or small — that you look forward to every year?", theme: "gratitude"),
        PromptEntry(text: "What's something about your city or neighbourhood that you love but rarely notice?", theme: "gratitude"),
        PromptEntry(text: "What's a piece of advice you're grateful someone gave you, even if you didn't want to hear it?", theme: "gratitude"),
        PromptEntry(text: "Who's someone that believed in you before you believed in yourself?", theme: "gratitude"),
        PromptEntry(text: "What's something you do just for yourself that makes you feel recharged?", theme: "gratitude"),
        PromptEntry(text: "What's a mistake that led to something unexpectedly good?", theme: "gratitude"),
        PromptEntry(text: "What's something you've gotten better at that you're quietly proud of?", theme: "gratitude"),
        // Wave 2 – deep
        PromptEntry(text: "What's one thing you do when no one is watching that reveals who you really are?", theme: "deep"),
        PromptEntry(text: "What chapter of your life would you most want to re-read?", theme: "deep"),
        PromptEntry(text: "What's something you've never forgiven yourself for?", theme: "deep"),
        PromptEntry(text: "What's the kindest thing you've ever done anonymously?", theme: "deep"),
        PromptEntry(text: "What does the best version of your future self look like?", theme: "deep"),
        PromptEntry(text: "What's an experience that fundamentally changed your values?", theme: "deep"),
        PromptEntry(text: "What's a question you're afraid to ask someone you love?", theme: "deep"),
        PromptEntry(text: "What would you most want your children — or younger people in your life — to learn from you?", theme: "deep"),
        PromptEntry(text: "What's a sacrifice you made that you've never talked about?", theme: "deep"),
        PromptEntry(text: "What's the most honest thing you could say about yourself right now?", theme: "deep"),
        // Wave 2 – playful
        PromptEntry(text: "What's a nickname you've had that you secretly liked?", theme: "playful"),
        PromptEntry(text: "If you could only communicate in movie quotes for a day, which movie would you pick?", theme: "playful"),
        PromptEntry(text: "What's the strangest thing you've ever collected?", theme: "playful"),
        PromptEntry(text: "What's a skill you pretend to have but really don't?", theme: "playful"),
        PromptEntry(text: "If your pet could talk, what's the first thing they'd say about you?", theme: "playful"),
        PromptEntry(text: "What's the most dramatic overreaction you've ever had?", theme: "playful"),
        PromptEntry(text: "What's your hidden talent that would win a very specific game show?", theme: "playful"),
        PromptEntry(text: "What's the best excuse you've invented to leave a party early?", theme: "playful"),
        PromptEntry(text: "If you could ban one word from the English language, what would it be?", theme: "playful"),
        PromptEntry(text: "What's a fictional world you'd actually want to live in?", theme: "playful"),
        // Wave 2 – gratitude
        PromptEntry(text: "What's a seemingly random event that ended up shaping your life?", theme: "gratitude"),
        PromptEntry(text: "What's a book, film or song that arrived exactly when you needed it?", theme: "gratitude"),
        PromptEntry(text: "What's something about getting older that you're actually glad about?", theme: "gratitude"),
        PromptEntry(text: "What's a quality in someone you love that you've started to develop in yourself?", theme: "gratitude"),
        PromptEntry(text: "What's a hard season of life that made you more compassionate?", theme: "gratitude"),
        PromptEntry(text: "What's a small ritual you have that quietly anchors your day?", theme: "gratitude"),
        PromptEntry(text: "What's something the person you're texting has done that you've never properly thanked them for?", theme: "gratitude"),
        PromptEntry(text: "What's something you have now that a past version of you desperately wanted?", theme: "gratitude"),
        PromptEntry(text: "What's a compliment you received that still sticks with you?", theme: "gratitude"),
        PromptEntry(text: "What's an ordinary day you'd love to bottle and keep forever?", theme: "gratitude"),
        // Wave 3 – deep
        PromptEntry(text: "What's a truth about the world you've had to accept even though it still hurts?", theme: "deep"),
        PromptEntry(text: "What's something you want to let go of before the year is over?", theme: "deep"),
        PromptEntry(text: "What does your gut tell you that your head refuses to hear?", theme: "deep"),
        PromptEntry(text: "What's a version of yourself you've had to grieve?", theme: "deep"),
        PromptEntry(text: "What matters to you more than you usually admit?", theme: "deep"),
        PromptEntry(text: "What's something you'd tell your teenage self if you could?", theme: "deep"),
        PromptEntry(text: "What's a question you've been avoiding asking yourself?", theme: "deep"),
        PromptEntry(text: "What's an act of courage you're most proud of?", theme: "deep"),
        PromptEntry(text: "What's a pattern in your relationships you keep repeating?", theme: "deep"),
        PromptEntry(text: "What part of your life do you feel most uncertain about right now?", theme: "deep"),
        // Wave 3 – playful
        PromptEntry(text: "What's a game you'd win every time if it were at the Olympics?", theme: "playful"),
        PromptEntry(text: "If you could design your perfect Saturday, what would it include?", theme: "playful"),
        PromptEntry(text: "What's an unwritten rule you think everyone should follow?", theme: "playful"),
        PromptEntry(text: "If you could eat only food from one country for the rest of your life, which country?", theme: "playful"),
        PromptEntry(text: "What's the most impressive thing you've ever done that nobody saw?", theme: "playful"),
        PromptEntry(text: "What's an app on your phone you're slightly addicted to but won't delete?", theme: "playful"),
        PromptEntry(text: "If you woke up as a dog for a day, what's the first thing you'd do?", theme: "playful"),
        PromptEntry(text: "What fictional villain do you secretly understand?", theme: "playful"),
        PromptEntry(text: "What's the most adventurous thing you've eaten?", theme: "playful"),
        PromptEntry(text: "If you could swap one chore for a different one, what swap would you make?", theme: "playful"),
        // Wave 3 – gratitude
        PromptEntry(text: "What's something your parents or guardians did right that you want to carry forward?", theme: "gratitude"),
        PromptEntry(text: "What's a friendship that surprised you by how deep it became?", theme: "gratitude"),
        PromptEntry(text: "What's something about your job or daily work that you genuinely value?", theme: "gratitude"),
        PromptEntry(text: "What's a lesson from nature — weather, seasons, animals — that's shaped how you think?", theme: "gratitude"),
        PromptEntry(text: "What's something you've created, built or grown that made you feel capable?", theme: "gratitude"),
        PromptEntry(text: "What's a gesture from someone that was tiny to them but huge to you?", theme: "gratitude"),
        PromptEntry(text: "What's something you're looking forward to next month, however small?", theme: "gratitude"),
        PromptEntry(text: "What's a way your life is easier than you sometimes remember to notice?", theme: "gratitude"),
        PromptEntry(text: "What's a quality in yourself that you've learned to appreciate rather than change?", theme: "gratitude"),
        PromptEntry(text: "What's a gift — not a physical object — someone gave you recently?", theme: "gratitude"),
        // Wave 4 – deep
        PromptEntry(text: "What's a rule you live by that you've never articulated out loud before?", theme: "deep"),
        PromptEntry(text: "What's the bravest thing you've ever done for someone else?", theme: "deep"),
        PromptEntry(text: "What are you afraid you might regret most in 20 years?", theme: "deep"),
        PromptEntry(text: "What's a conversation that repaired something you thought was broken for good?", theme: "deep"),
        PromptEntry(text: "What's a story from your family history that says everything about where you came from?", theme: "deep"),
        PromptEntry(text: "What emotion do you find hardest to express, and why?", theme: "deep"),
        PromptEntry(text: "What's a moment when you realized you'd become an adult?", theme: "deep"),
        PromptEntry(text: "What would you do with six months with no obligations and unlimited resources?", theme: "deep"),
        PromptEntry(text: "What's the most important decision you've ever made?", theme: "deep"),
        PromptEntry(text: "What's something you feel the world needs more of right now?", theme: "deep"),
        // Wave 4 – playful
        PromptEntry(text: "What's your most surprising hidden interest that no one suspects?", theme: "playful"),
        PromptEntry(text: "If you could only eat one meal for an entire year, what would it be?", theme: "playful"),
        PromptEntry(text: "What's a superpower that sounds lame but would actually be incredibly useful?", theme: "playful"),
        PromptEntry(text: "What's the most elaborate lie you told as a child?", theme: "playful"),
        PromptEntry(text: "If you had to teach a class on something, what would it be?", theme: "playful"),
        PromptEntry(text: "What's a show from your childhood you'd reboot immediately if you could?", theme: "playful"),
        PromptEntry(text: "If you could live inside any book for a month, which would you pick?", theme: "playful"),
        PromptEntry(text: "What's the strangest hobby you've ever tried?", theme: "playful"),
        PromptEntry(text: "What's something that's universally considered cool but you genuinely don't get?", theme: "playful"),
        PromptEntry(text: "If money weren't a factor, what job would you do just for fun?", theme: "playful"),
        // Wave 4 – gratitude
        PromptEntry(text: "What's a technology you're genuinely grateful exists in your lifetime?", theme: "gratitude"),
        PromptEntry(text: "What's a habit someone modelled for you that you didn't realize you needed?", theme: "gratitude"),
        PromptEntry(text: "What's a moment of beauty you witnessed that you still think about?", theme: "gratitude"),
        PromptEntry(text: "What's something in your home that brings you quiet joy every day?", theme: "gratitude"),
        PromptEntry(text: "What's a dream that came true in a way you didn't expect?", theme: "gratitude"),
        PromptEntry(text: "Who's someone you'd like to reconnect with, and what would you want to say?", theme: "gratitude"),
        PromptEntry(text: "What's a chapter of your life you look back on with unexpected warmth?", theme: "gratitude"),
        PromptEntry(text: "What's the most beautiful place you've ever stood?", theme: "gratitude"),
        PromptEntry(text: "What's a change in yourself that you're genuinely proud of?", theme: "gratitude"),
        PromptEntry(text: "What's one thing about the person you're texting that you admire but rarely say?", theme: "gratitude"),
        // Wave 5 – deep
        PromptEntry(text: "What's something you know is true about yourself that's still hard to admit?", theme: "deep"),
        PromptEntry(text: "What's a version of your future you've given up on, and how do you feel about that?", theme: "deep"),
        PromptEntry(text: "What's something you learned from a loss that you wouldn't trade away?", theme: "deep"),
        PromptEntry(text: "What's a tension in your life you've stopped trying to resolve?", theme: "deep"),
        PromptEntry(text: "When did you feel most alive this past year?", theme: "deep"),
        PromptEntry(text: "What's a question about your own life you don't have an answer to yet?", theme: "deep"),
        PromptEntry(text: "What's something you've changed your approach to — and why?", theme: "deep"),
        PromptEntry(text: "What's a value you hold that you haven't always lived up to?", theme: "deep"),
        PromptEntry(text: "What do you wish your closest people understood about how you tick?", theme: "deep"),
        PromptEntry(text: "What's a story about yourself that you've been telling wrong?", theme: "deep"),
        // Wave 5 – playful
        PromptEntry(text: "What's a word you use way too often and can't seem to stop?", theme: "playful"),
        PromptEntry(text: "If someone followed you around with a camera for a day, what would surprise them most?", theme: "playful"),
        PromptEntry(text: "What's the most niche corner of the internet you've fallen down?", theme: "playful"),
        PromptEntry(text: "If you could instantly know one fact about the universe, what would you ask?", theme: "playful"),
        PromptEntry(text: "What's a smell that immediately transports you somewhere?", theme: "playful"),
        PromptEntry(text: "What's something you're secretly very competitive about?", theme: "playful"),
        PromptEntry(text: "What's the weirdest dream you've had recently?", theme: "playful"),
        PromptEntry(text: "What's a social norm you've quietly decided you don't follow?", theme: "playful"),
        PromptEntry(text: "If you had to describe your personality as a weather pattern, what would it be?", theme: "playful"),
        PromptEntry(text: "What's a compliment that would genuinely make your whole week?", theme: "playful"),
        // Wave 5 – gratitude
        PromptEntry(text: "What's a mundane moment from your week that, looking back, felt peaceful?", theme: "gratitude"),
        PromptEntry(text: "What's something your body has recovered from that you're amazed by?", theme: "gratitude"),
        PromptEntry(text: "What's a habit someone else has that inspired you to change your own?", theme: "gratitude"),
        PromptEntry(text: "What's the most unexpectedly kind thing a stranger has done for you this year?", theme: "gratitude"),
        PromptEntry(text: "What's something you've said 'no' to that freed up space for something better?", theme: "gratitude"),
        PromptEntry(text: "What's a corner of your life that's working better than you usually admit?", theme: "gratitude"),
        PromptEntry(text: "What's something you were wrong about that you're actually glad you got to correct?", theme: "gratitude"),
        PromptEntry(text: "What's a song that's rescued a bad mood more than once?", theme: "gratitude"),
        PromptEntry(text: "What's the most supportive thing someone said to you during a hard time?", theme: "gratitude"),
        PromptEntry(text: "What's something in your life right now that future-you would thank present-you for doing?", theme: "gratitude"),
        // Wave 6 (to hit 400+)
        PromptEntry(text: "What's the last thing that made you feel genuinely connected to another person?", theme: "deep"),
        PromptEntry(text: "If you could spend a day as another person in your life, who would you pick?", theme: "playful"),
        PromptEntry(text: "What's the smallest act of kindness you've received that stayed with you?", theme: "gratitude"),
        PromptEntry(text: "What's something you've always meant to ask a family member but never have?", theme: "deep"),
        PromptEntry(text: "What's the most unexpected place you found comfort?", theme: "gratitude"),
        PromptEntry(text: "What's a hobby you started as a joke but ended up loving?", theme: "playful"),
        PromptEntry(text: "What's a difficult emotion you've been avoiding this week?", theme: "deep"),
        PromptEntry(text: "What's the most important quality you look for in a friend?", theme: "deep"),
        PromptEntry(text: "What's something you wish you could explain to everyone you meet?", theme: "deep"),
        PromptEntry(text: "If you could have dinner with anyone from history, who and why?", theme: "playful"),
        PromptEntry(text: "What's a beautiful thing you saw this week that no one else noticed?", theme: "gratitude"),
        PromptEntry(text: "What's a principle you try to teach others by example?", theme: "deep"),
        PromptEntry(text: "What's the funniest misuse of technology you've witnessed?", theme: "playful"),
        PromptEntry(text: "What's something you're grateful for that wouldn't have existed 10 years ago?", theme: "gratitude"),
        PromptEntry(text: "What's a goal you're afraid to say out loud in case you don't reach it?", theme: "deep"),
        PromptEntry(text: "What's the most surreal experience you've ever had?", theme: "playful"),
        PromptEntry(text: "What's a part of your culture or heritage you most want to preserve?", theme: "gratitude"),
        PromptEntry(text: "What's the one thing you want people to know about you that they usually don't?", theme: "deep"),
        PromptEntry(text: "What's a meal that brings back a specific memory every time you eat it?", theme: "gratitude"),
        PromptEntry(text: "What's something you hope never changes about yourself?", theme: "deep"),
    ]
}
