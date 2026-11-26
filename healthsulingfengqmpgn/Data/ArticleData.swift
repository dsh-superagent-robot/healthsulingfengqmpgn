import SwiftUI

enum ArticleLayout: String {
    case vertical, horizontal
}

struct ArticleDefinition: Identifiable, Hashable {
    let id: String
    let categoryKey: String
    let slug: String
    let title: String
    let pageCount: Int
    let isPopular: Bool
    let color: Color

    var referenceKey: String { id }
    var category: ArticleCategoryDefinition? {
        ArticleCatalog.categories.first { $0.id == categoryKey }
    }
}

struct ArticleCategoryDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let layout: ArticleLayout
    let sourceURL: URL
    let icon: String
    let color: Color
    let articles: [ArticleDefinition]

    var horizontal: Bool { layout == .horizontal }
}

struct ArticlePage: Identifiable {
    let id: Int
    let title: String
    let lead: String
    let body: String
}

enum ArticleCatalog {
    static let categories: [ArticleCategoryDefinition] = buildCategories()

    static let allArticles: [ArticleDefinition] = categories.flatMap(\.articles)

    static let popular: [ArticleDefinition] = allArticles.filter(\.isPopular)

    static func category(_ key: String) -> ArticleCategoryDefinition? {
        categories.first { $0.id == key }
    }

    static func article(forReference reference: String) -> ArticleDefinition? {
        let key = reference.replacingOccurrences(of: ".title", with: "")
        return allArticles.first { $0.id == key }
    }

    static func articles(in category: ArticleCategoryDefinition) -> [ArticleDefinition] {
        category.articles
    }

    static func pages(for article: ArticleDefinition) -> [ArticlePage] {
        let templates = self.templates[article.categoryKey] ?? genericTemplates
        return (0..<article.pageCount).map { index in
            let template = templates[index % templates.count]
            let isFirst = index == 0
            let isLast = index == article.pageCount - 1
            var lead = template.lead
            var body = template.body
            if isFirst {
                lead = "\(article.title): \(template.lead)"
            }
            if isLast {
                body += " Bring this into your own routine one small step at a time, and keep measuring to see how your body responds."
            }
            return ArticlePage(id: index, title: template.title, lead: lead, body: body)
        }
    }

    // MARK: Build

    private static func buildCategories() -> [ArticleCategoryDefinition] {
        let hrvBasics = makeCategory(
            key: "hrv.basics",
            title: "HRV Basics",
            subtitle: "Start here: what heart rate variability means",
            layout: .vertical,
            source: "https://my.clevelandclinic.org/health/diagnostics/23345-heart-rate-variability",
            icon: "waveform.path.ecg",
            color: Color(hex: 0x6CD1CC),
            articles: [
                ("what_is_hrv", "What Is HRV?", 3, false),
                ("how_hrv_works", "How HRV Works", 4, true),
                ("what_affects_hrv", "What Affects HRV", 3, false),
                ("measuring_hrv", "Measuring HRV", 3, false),
                ("improving_hrv", "Improving HRV", 3, false)
            ]
        )
        let hrvExplained = makeCategory(
            key: "hrv.explained",
            title: "HRV Explained",
            subtitle: "The science behind the signal",
            layout: .vertical,
            source: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/",
            icon: "brain.head.profile",
            color: Color(hex: 0x8287D9),
            articles: [
                ("definition", "HRV: A Definition", 3, false),
                ("variability", "Variability, Explained", 3, false),
                ("clinical_significance", "Clinical Significance", 3, false),
                ("psychological_aspects", "Psychological Aspects", 3, false),
                ("analysis_methods", "Analysis Methods", 3, false),
                ("physiological_correlates", "Physiological Correlates", 3, false),
                ("artifact_and_limits", "Artifacts & Limits", 2, false)
            ]
        )
        let hrvContext = makeCategory(
            key: "hrv.context",
            title: "Context & Recovery",
            subtitle: "Why the same number can mean different things",
            layout: .horizontal,
            source: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/",
            icon: "square.stack.3d.up.fill",
            color: Color(hex: 0xD482D9),
            articles: [
                ("why_context_matters", "Why Context Matters", 7, false),
                ("rest_and_recovery", "Rest & Recovery", 7, true),
                ("readiness_and_load", "Readiness & Load", 7, false),
                ("food_and_metabolism", "Food & Metabolism", 7, true),
                ("personalization_and_tags", "Personalization & Tags", 7, false),
                ("decrease_interpretation", "When HRV Drops", 7, false)
            ]
        )
        let ppg = makeCategory(
            key: "ppg.explained",
            title: "PPG Explained",
            subtitle: "How a camera can see your pulse",
            layout: .vertical,
            source: "https://en.wikipedia.org/wiki/Photoplethysmogram",
            icon: "camera.macro",
            color: Color(hex: 0x82B2D9),
            articles: [
                ("fundamentals", "PPG Fundamentals", 7, true),
                ("measurement_methods", "Measurement Methods", 7, false),
                ("signal_analysis", "Signal Analysis", 7, false),
                ("clinical_use", "Clinical Use", 7, false),
                ("limitations_and_artifacts", "Limitations & Artifacts", 7, false)
            ]
        )
        let ecg = makeCategory(
            key: "ecg",
            title: "ECG",
            subtitle: "The electrical map of your heart",
            layout: .vertical,
            source: "https://www.mayoclinic.org/tests-procedures/ekg/about/pac-20384983",
            icon: "waveform.path",
            color: Color(hex: 0xD98287),
            articles: [
                ("about", "ECG: The Basics", 5, true),
                ("why", "Why an ECG?", 5, false),
                ("types", "Types of ECG", 5, false),
                ("procedure", "The Procedure", 5, false),
                ("results", "Reading Results", 5, false),
                ("symptoms", "Symptoms to Watch", 4, true),
                ("safe", "Is It Safe?", 3, false),
                ("after", "After the Test", 4, false),
                ("screening", "Screening", 4, true),
                ("facts", "ECG Facts", 5, true)
            ]
        )
        let arrhythmia = makeCategory(
            key: "arrhythmia",
            title: "Arrhythmia",
            subtitle: "When the rhythm changes",
            layout: .vertical,
            source: "https://www.heart.org/en/health-topics/arrhythmia",
            icon: "bolt.heart.fill",
            color: Color(hex: 0xD9A982),
            articles: [
                ("about", "About Arrhythmia", 5, false),
                ("types", "Types of Arrhythmia", 5, true),
                ("heart", "The Heart's Circuit", 5, false),
                ("circuit", "Electrical Pathways", 5, false),
                ("causes", "Common Causes", 5, false),
                ("misfiring", "When Signals Misfire", 5, true),
                ("diagnosing", "Diagnosing Arrhythmia", 5, false),
                ("normal", "When It's Normal", 5, false),
                ("kids", "Arrhythmia in Kids", 5, false),
                ("livingwith", "Living With Arrhythmia", 5, false)
            ]
        )
        let heartAttack = makeCategory(
            key: "heartattack",
            title: "Heart Attack",
            subtitle: "Know the signs, protect your heart",
            layout: .horizontal,
            source: "https://www.heart.org/en/health-topics/heart-attack",
            icon: "heart.slash.fill",
            color: Color(hex: 0xD982B2),
            articles: [
                ("about", "Heart Attack Basics", 5, false),
                ("damage", "Heart Muscle Damage", 5, false),
                ("recovery", "Recovery", 5, true),
                ("signs", "Warning Signs", 5, true),
                ("terms", "Terms to Know", 5, false),
                ("othertriggers", "Lesser-Known Triggers", 5, false),
                ("arrest", "Cardiac Arrest", 5, false),
                ("prevention", "Prevention", 5, true),
                ("hopeafter", "Hope After", 5, false),
                ("takeaways", "Key Takeaways", 5, false)
            ]
        )
        let sleep = makeCategory(
            key: "sleep",
            title: "Sleep",
            subtitle: "The nightly reset your heart needs",
            layout: .vertical,
            source: "https://www.nhlbi.nih.gov/health/sleep-deprivation",
            icon: "moon.stars.fill",
            color: Color(hex: 0xA982D9),
            articles: [
                ("about", "Sleep & Your Heart", 5, false),
                ("benefits", "Benefits of Sleep", 6, true),
                ("science", "The Science of Sleep", 5, false),
                ("sleepy", "Why You Feel Sleepy", 5, false),
                ("safety", "Sleep Safety", 5, false),
                ("timing", "Sleep Timing", 5, true),
                ("myths", "Sleep Myths", 5, true),
                ("disrupt", "Sleep Disruptors", 5, true),
                ("tips", "Sleep Tips", 5, true),
                ("disorder", "Sleep Disorders", 5, false)
            ]
        )
        let stress = makeCategory(
            key: "stress",
            title: "Stress",
            subtitle: "How pressure travels through the body",
            layout: .vertical,
            source: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5579396/",
            icon: "bolt.fill",
            color: Color(hex: 0xD5CF65),
            articles: [
                ("about", "Stress & the Body", 5, false),
                ("brain", "Stress & the Brain", 6, true),
                ("memory", "Stress & Memory", 6, false),
                ("cognition", "Stress & Cognition", 5, false),
                ("immunity", "Stress & Immunity", 5, true),
                ("cardio", "Stress & the Heart", 5, false),
                ("gastro", "Stress & Digestion", 5, false),
                ("hormones", "Stress Hormones", 5, false),
                ("allsystems", "All Systems", 5, true),
                ("managing", "Managing Stress", 5, false)
            ]
        )
        let activity = makeCategory(
            key: "activity",
            title: "Activity",
            subtitle: "Move well, recover better",
            layout: .horizontal,
            source: "https://www.heart.org/en/healthy-living/fitness",
            icon: "figure.run",
            color: Color(hex: 0x84D47F),
            articles: [
                ("howtostart", "How to Start", 5, false),
                ("benefits", "Exercise Benefits", 5, true),
                ("recforadults", "Recommendations for Adults", 5, false),
                ("recforkids", "Recommendations for Kids", 5, false),
                ("types", "Types of Activity", 5, true),
                ("firststeps", "First Steps", 5, false),
                ("intensity", "Intensity", 5, false),
                ("movement", "Movement Snacks", 5, true),
                ("motivation", "Motivation", 5, false),
                ("push", "Push Days", 5, true)
            ]
        )
        return [hrvBasics, hrvExplained, hrvContext, ppg, ecg, arrhythmia, heartAttack, sleep, stress, activity]
    }

    private static func makeCategory(
        key: String,
        title: String,
        subtitle: String,
        layout: ArticleLayout,
        source: String,
        icon: String,
        color: Color,
        articles: [(String, String, Int, Bool)]
    ) -> ArticleCategoryDefinition {
        let definitions = articles.map { item in
            ArticleDefinition(
                id: "article.\(key).\(item.0)",
                categoryKey: key,
                slug: item.0,
                title: item.1,
                pageCount: item.2,
                isPopular: item.3,
                color: color
            )
        }
        return ArticleCategoryDefinition(
            id: key,
            title: title,
            subtitle: subtitle,
            layout: layout,
            sourceURL: URL(string: source)!,
            icon: icon,
            color: color,
            articles: definitions
        )
    }

    // MARK: Content templates

    private struct Template {
        let title: String
        let lead: String
        let body: String
    }

    private static let genericTemplates: [Template] = [
        Template(
            title: "Start with the signal",
            lead: "Your body is always communicating.",
            body: "Small changes in timing and rhythm carry useful information. Looking at patterns over days, rather than one isolated reading, gives a calmer and more useful picture."
        ),
        Template(
            title: "Build a baseline",
            lead: "Context turns numbers into meaning.",
            body: "A measurement is a snapshot. Repeated measurements in similar conditions create a baseline, and that baseline helps you notice meaningful change instead of normal day-to-day noise."
        ),
        Template(
            title: "Practice gently",
            lead: "Consistency beats intensity.",
            body: "Short, regular check-ins are easier to sustain than occasional long sessions. Pick a moment that fits your day and let the routine do the work."
        )
    ]

    private static let templates: [String: [Template]] = [
        "hrv.basics": [
            Template(
                title: "Two beats, two intervals",
                lead: "HRV is the variation in time between heartbeats.",
                body: "A heart does not tick like a metronome. Even at rest, the gap between beats shifts slightly from one beat to the next. Heart rate variability describes that natural variation and is a window into how the autonomic nervous system is balancing activation and recovery."
            ),
            Template(
                title: "The autonomic balance",
                lead: "Your nervous system constantly adjusts your heart.",
                body: "The sympathetic branch prepares you for action, while the parasympathetic branch supports rest and digestion. Higher variability at rest is often associated with a flexible, well-recovered system that can shift between these states easily."
            ),
            Template(
                title: "What the numbers mean",
                lead: "One reading is a snapshot, not a verdict.",
                body: "HRV changes with sleep, hydration, illness, training and emotion. Tracking it alongside context tags helps separate a meaningful trend from a temporary fluctuation. Use the trend as a conversation starter, never as a diagnosis."
            ),
            Template(
                title: "Why the camera works",
                lead: "A fingertip pulse reveals rhythmic blood flow.",
                body: "Photoplethysmography measures tiny changes in light absorption as blood moves through the fingertip. From that pulse wave the app estimates beat-to-beat intervals and then derives HRV metrics such as RMSSD, SDNN and pNN50."
            )
        ],
        "hrv.explained": [
            Template(
                title: "Defining variability",
                lead: "Variability is the language of adaptation.",
                body: "A healthy system is not perfectly regular. It responds to breathing, movement and emotion. HRV captures that responsiveness using time-domain and frequency-domain measures, each highlighting a different part of the picture."
            ),
            Template(
                title: "Time-domain measures",
                lead: "RMSSD, SDNN and pNN50 each tell a different story.",
                body: "RMSSD reflects short-term beat-to-beat change and is closely tied to parasympathetic activity. SDNN captures overall variability across the recording. pNN50 reports the share of successive intervals that differ by more than 50 milliseconds."
            ),
            Template(
                title: "The bigger context",
                lead: "Numbers need a person around them.",
                body: "Age, fitness, medication and stress all influence what is normal for you. Comparing your readings with your own history is more informative than comparing them with someone else's values."
            ),
            Template(
                title: "Limitations matter",
                lead: "Good decisions respect uncertainty.",
                body: "Movement, cold fingers, bright light and irregular contact all affect optical measurements. A single artifact-prone recording should not drive a big decision. Repeat the measurement when conditions are comfortable and consistent."
            )
        ],
        "hrv.context": [
            Template(
                title: "Same number, different story",
                lead: "Context is what turns a reading into insight.",
                body: "A dip after a hard workout is not the same as a dip after a poor night's sleep. Tagging the moment before or after an activity helps the app explain what changed and why it might have changed."
            ),
            Template(
                title: "Sleep and recovery",
                lead: "The night shapes the morning.",
                body: "Sleep is when the body repairs and the nervous system rebalances. Measuring after waking can show how well you recovered. Measuring before bed can show how the day is landing in your body."
            ),
            Template(
                title: "Readiness and load",
                lead: "Recovery is a skill you can train.",
                body: "Tracking before and after exercise reveals how your heart responds to load. A gradual return toward baseline is often a good sign. Persistent suppression deserves rest, hydration and attention rather than another push."
            ),
            Template(
                title: "Food and metabolism",
                lead: "Digestion shifts blood flow and heart rhythm.",
                body: "Meals can temporarily change heart rate and HRV as the body redirects resources. Before and after meal tags help you understand your own pattern instead of assuming that every change is stress."
            )
        ],
        "ppg.explained": [
            Template(
                title: "Light meets blood",
                lead: "PPG shines light through the skin and watches what comes back.",
                body: "Blood absorbs more light than surrounding tissue. With each heartbeat the volume of blood in the fingertip changes, modulating the light that reaches the camera. The result is a pulse waveform rich in timing information."
            ),
            Template(
                title: "From waveform to beats",
                lead: "Peak detection recovers the beat sequence.",
                body: "Signal processing identifies each pulse peak, filters out noise and measures the interval between peaks. Those intervals are the raw material for heart rate, HRV, stress and energy estimates."
            ),
            Template(
                title: "Quality over quantity",
                lead: "A clean signal is worth more than a long noisy one.",
                body: "The app checks frame brightness, finger coverage and motion. Frames outside the acceptable range are rejected so that unstable periods do not distort the final result."
            ),
            Template(
                title: "Know the boundaries",
                lead: "PPG is a wellness tool, not a medical device.",
                body: "Optical measurement cannot diagnose arrhythmia or heart disease. If you feel unwell or notice persistent irregularities, seek professional care rather than relying on an app."
            )
        ],
        "ecg": [
            Template(
                title: "The electrical view",
                lead: "An ECG records the heart's electrical activity.",
                body: "Each heartbeat begins with an electrical signal. Electrodes on the skin detect those signals and display them as waves, giving clinicians a detailed view of rhythm and conduction."
            ),
            Template(
                title: "Why it is used",
                lead: "ECG helps answer specific questions.",
                body: "It can reveal rhythm disturbances, conduction blocks, signs of reduced blood flow and changes after a cardiac event. It is quick, painless and often part of a routine check."
            ),
            Template(
                title: "Preparation and safety",
                lead: "The test itself is low risk.",
                body: "You may be asked to lie still while a technician places electrodes. The recording takes only minutes. Your skin may be cleaned and sticky patches removed afterwards."
            ),
            Template(
                title: "Reading the waves",
                lead: "A clinician interprets the pattern, not a single number.",
                body: "The P wave, QRS complex and T wave each represent part of the cardiac cycle. Their timing, shape and relationship help identify what is happening in the heart."
            )
        ],
        "arrhythmia": [
            Template(
                title: "Rhythm and regulation",
                lead: "Arrhythmia means the rhythm is different from usual.",
                body: "The heart's electrical system keeps a steady beat. When signals are early, delayed or follow an unusual path, the rhythm can feel fast, slow or irregular. Many changes are harmless, while others need care."
            ),
            Template(
                title: "Common patterns",
                lead: "There are many types of rhythm change.",
                body: "Atrial fibrillation, premature beats and supraventricular tachycardia are familiar examples. Each has its own pattern and clinical meaning, which is why an ECG is more useful than a wrist notification alone."
            ),
            Template(
                title: "Listen to symptoms",
                lead: "How you feel matters alongside the tracing.",
                body: "Palpitations, lightheadedness, chest discomfort or fainting should be discussed with a clinician. Seek urgent help for severe chest pain, collapse or difficulty breathing."
            ),
            Template(
                title: "Living well",
                lead: "Most rhythm conditions can be managed.",
                body: "Treatment may include monitoring, medication, lifestyle changes or procedures. Keep follow-up appointments, limit excess alcohol and caffeine if advised, and ask questions so you understand your plan."
            )
        ],
        "heartattack": [
            Template(
                title: "Time is muscle",
                lead: "A heart attack is a medical emergency.",
                body: "When blood flow to the heart muscle is blocked, every minute matters. Calling emergency services early is the most important action. Do not drive yourself to hospital when you suspect a heart attack."
            ),
            Template(
                title: "Know the signs",
                lead: "Symptoms are not always dramatic.",
                body: "Chest pressure, pain spreading to the arm or jaw, shortness of breath, sweating, nausea and unusual fatigue are common. Women, older adults and people with diabetes may have subtler symptoms."
            ),
            Template(
                title: "Recovery is a programme",
                lead: "Cardiac rehabilitation helps rebuild confidence.",
                body: "Recovery includes medication, gradual activity, nutrition and emotional support. A structured rehabilitation programme can improve quality of life and reduce the risk of another event."
            ),
            Template(
                title: "Lower the next risk",
                lead: "Small sustainable changes add up.",
                body: "Managing blood pressure, cholesterol and blood sugar, avoiding tobacco, moving regularly and sleeping well all support long-term heart health. Work with your care team on targets that fit you."
            )
        ],
        "sleep": [
            Template(
                title: "Sleep is active repair",
                lead: "The sleeping brain still works hard.",
                body: "Sleep supports memory, immune function, hormone balance and cardiovascular recovery. Both duration and regularity matter, and the body responds well to a consistent wind-down routine."
            ),
            Template(
                title: "Build a wind-down",
                lead: "Your heart notices the transition.",
                body: "Dim light, cooler air and a predictable sequence of quiet activities signal that the day is ending. Reducing late caffeine and heavy meals can also help the nervous system settle."
            ),
            Template(
                title: "Track gently",
                lead: "Sleep data should reduce pressure, not add it.",
                body: "A single poor night is normal. Look at weekly patterns and how you feel during the day. Measuring HRV after waking can show how your body is recovering without turning sleep into a performance test."
            ),
            Template(
                title: "When to seek help",
                lead: "Persistent sleep problems deserve attention.",
                body: "Loud snoring, pauses in breathing, daytime sleepiness or insomnia that lasts for weeks are worth discussing with a clinician. Treating a sleep disorder can improve mood, energy and heart health."
            )
        ],
        "stress": [
            Template(
                title: "The stress response",
                lead: "Short bursts of stress can be useful.",
                body: "The body releases hormones that sharpen attention and raise heart rate. The system is designed to return to baseline afterwards. Problems arise when activation becomes frequent or prolonged."
            ),
            Template(
                title: "Mind and body",
                lead: "Stress is not just a feeling.",
                body: "Chronic stress can affect sleep, digestion, immunity, blood pressure and mood. HRV often becomes less flexible under sustained load, which is why trends across days are more informative than one reading."
            ),
            Template(
                title: "Recovery tools",
                lead: "Calm is a trainable state.",
                body: "Slow breathing, a short walk, daylight, time with people you trust and mindful pauses can all shift the nervous system toward recovery. Choose one small practice and repeat it."
            ),
            Template(
                title: "Seek support",
                lead: "You do not have to manage everything alone.",
                body: "Talking to a professional can help when stress feels unmanageable or begins to affect daily life. Support is a sign of strength, and early help often prevents a deeper crisis."
            )
        ],
        "activity": [
            Template(
                title: "Start where you are",
                lead: "Movement does not need to be a workout.",
                body: "A ten-minute walk, a stretch or taking the stairs count. Begin at a level that feels sustainable and build gradually. Consistency matters more than a perfect plan."
            ),
            Template(
                title: "Load and recovery",
                lead: "Exercise is a stress that makes you stronger.",
                body: "Training creates a temporary challenge; recovery turns it into adaptation. Alternating harder days with easier days helps the cardiovascular system respond well."
            ),
            Template(
                title: "Measure the response",
                lead: "Your heart data can guide pacing.",
                body: "Checking HRV before and after exercise can show how your body is handling load. If variability stays low and resting heart rate remains elevated, an easier day may be the smarter choice."
            ),
            Template(
                title: "Make it stick",
                lead: "Joy is a better long-term motivator than guilt.",
                body: "Pick activities you can look forward to, put them in your calendar and invite someone along. Missing a day is not failure; returning is the skill."
            )
        ]
    ]
}
