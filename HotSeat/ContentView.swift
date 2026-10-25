import SwiftUI

enum AppScreen {
    case home
    case rank
    case speedTap
    case laneDodge
    case tugOfWar
    case headsUp
    case ticTacToe
    case simon
    case laserEyes
    case chocolateRain
    case vocalGlide
    case choiceGate
    case ultimateTTT
}

@Observable
final class AppViewModel {
    var screen: AppScreen = .home

    func openRank() {
        screen = .rank
    }

    func openSpeedTap() {
        screen = .speedTap
    }

    func openLaneDodge() {
        screen = .laneDodge
    }

    func openTugOfWar() {
        screen = .tugOfWar
    }

    func openHeadsUp() {
        screen = .headsUp
    }

    func openTicTacToe() {
        screen = .ticTacToe
    }

    func openSimon() {
        screen = .simon
    }

    func openLaserEyes() {
        screen = .laserEyes
    }

    func openChocolateRain() {
        screen = .chocolateRain
    }

    func openVocalGlide() {
        screen = .vocalGlide
    }

    func openChoiceGate() {
        screen = .choiceGate
    }

    func openUltimateTTT() {
        screen = .ultimateTTT
    }

    func goHome() {
        screen = .home
    }
}

/// Holds the live face signals emitted by the camera layer.
@Observable
final class FaceTracker {
    /// Forehead point in full-screen coordinates (points), or nil if no face.
    var foreheadPoint: CGPoint?
    /// Head tilt in radians, or nil if no face.
    var roll: CGFloat?
    /// Normalized X-centers (0...1) of up to 2 detected faces, sorted ascending.
    var faceCentersX: [CGFloat] = []
    /// True when the tracked face's mouth is open (nil if no face).
    var mouthOpen: Bool?
    /// Mouth center in full-screen view coordinates, or nil if no face.
    var mouthCenter: CGPoint?
    /// Nose tip in full-screen view coordinates, or nil if no landmarks.
    var noseTip: CGPoint?
    /// Face yaw in radians, or nil if no face.
    var yaw: CGFloat?
    /// Face pitch in radians, or nil if no face.
    var pitch: CGFloat?
    /// Left eye center in full-screen view coordinates, or nil if no landmarks.
    var leftEyeCenter: CGPoint?
    /// Right eye center in full-screen view coordinates, or nil if no landmarks.
    var rightEyeCenter: CGPoint?
    /// Bounding rect of outer lips in full-screen view coordinates, or nil if no landmarks.
    var mouthRect: CGRect?
    /// Screen-space width of the largest face bounding box (for dynamic hitbox scaling).
    var faceBBoxWidth: CGFloat?
    /// Per-face expressions for up to 2 detected faces, sorted by X ascending.
    var perFaceExpressions: [PerFaceExpression] = []
}

struct RankCategory: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let items: [String]
}

let allCategories: [RankCategory] = [
    // Food
    RankCategory(name: "Comfort Foods", emoji: "🍕", items: [
        "Pizza", "Mac & Cheese", "Grilled Cheese", "Chicken Nuggets", "Mashed Potatoes",
        "Ice Cream", "French Fries", "Tacos", "Brownies", "PB&J"
    ]),
    RankCategory(name: "Ice Cream Flavors", emoji: "🍦", items: [
        "Chocolate", "Vanilla", "Strawberry", "Cookie Dough", "Mint Chip",
        "Rocky Road", "Birthday Cake", "Cookies & Cream"
    ]),
    RankCategory(name: "Breakfast Foods", emoji: "🥞", items: [
        "Pancakes", "Waffles", "French Toast", "Cereal", "Bacon",
        "Scrambled Eggs", "Smoothie Bowl", "Breakfast Burrito"
    ]),
    RankCategory(name: "Pizza Toppings", emoji: "🧀", items: [
        "Pepperoni", "Extra Cheese", "Mushrooms", "Pineapple", "Sausage",
        "Olives", "Green Peppers", "BBQ Chicken"
    ]),
    RankCategory(name: "Candy & Sweets", emoji: "🍬", items: [
        "Skittles", "M&Ms", "Sour Patch Kids", "Gummy Bears", "Kit Kat",
        "Reese's", "Twizzlers", "Jolly Ranchers"
    ]),
    RankCategory(name: "Snack Time", emoji: "🍿", items: [
        "Popcorn", "Goldfish Crackers", "Apple Slices", "Pretzels",
        "String Cheese", "Chips & Salsa", "Trail Mix", "Fruit Snacks"
    ]),

    // Movies & TV (kid-friendly)
    RankCategory(name: "Pixar Films", emoji: "🎬", items: [
        "Ratatouille", "The Incredibles", "Up", "WALL-E", "Finding Nemo",
        "Toy Story", "Inside Out", "Coco"
    ]),
    RankCategory(name: "Disney Animated Movies", emoji: "🏰", items: [
        "The Lion King", "Moana", "Frozen", "Tangled", "Encanto",
        "Aladdin", "The Little Mermaid", "Big Hero 6"
    ]),
    RankCategory(name: "Disney Villains", emoji: "😈", items: [
        "Scar", "Ursula", "Maleficent", "Jafar", "Cruella De Vil",
        "Hades", "Captain Hook", "Gaston"
    ]),
    RankCategory(name: "Cartoon Shows", emoji: "📺", items: [
        "SpongeBob", "Gravity Falls", "Avatar: The Last Airbender",
        "Phineas and Ferb", "The Owl House", "Bluey",
        "Amphibia", "Teen Titans"
    ]),
    RankCategory(name: "Animated Movie Sidekicks", emoji: "🐾", items: [
        "Donkey (Shrek)", "Olaf (Frozen)", "Mushu (Mulan)", "Genie (Aladdin)",
        "Dory (Finding Nemo)", "Groot (Guardians)", "Baymax (Big Hero 6)", "Pascal (Tangled)"
    ]),
    RankCategory(name: "Superhero Movies", emoji: "🦸", items: [
        "Spider-Man: Into the Spider-Verse", "The Incredibles", "Black Panther",
        "Guardians of the Galaxy", "Big Hero 6", "Shazam!",
        "Spider-Man: No Way Home", "Thor: Ragnarok"
    ]),

    // Musical Theatre
    RankCategory(name: "Broadway Musicals", emoji: "🎭", items: [
        "Hamilton", "Wicked", "The Lion King", "Dear Evan Hansen",
        "Matilda", "Annie", "Newsies", "Into the Woods"
    ]),
    RankCategory(name: "Broadway Songs", emoji: "🎶", items: [
        "Defying Gravity", "My Shot", "Tomorrow", "Let It Go",
        "Seize the Day", "When I Grow Up", "Popular", "Do-Re-Mi"
    ]),
    RankCategory(name: "Musical Movie Adaptations", emoji: "🎥", items: [
        "The Greatest Showman", "Hairspray", "Into the Woods", "Annie",
        "West Side Story", "Matilda", "The Sound of Music", "Mary Poppins"
    ]),
    RankCategory(name: "Musical Characters", emoji: "🌟", items: [
        "Elphaba (Wicked)", "Alexander Hamilton", "Annie", "Simba (Lion King)",
        "Tracy Turnblad (Hairspray)", "Matilda", "Evan Hansen", "Mary Poppins"
    ]),
    RankCategory(name: "Disney Park Songs", emoji: "🎠", items: [
        "It's a Small World", "Yo Ho (A Pirate's Life for Me)",
        "The Haunted Mansion Theme", "Zip-A-Dee-Doo-Dah",
        "A Whole New World", "Under the Sea", "Be Our Guest", "Circle of Life"
    ]),

    // Music (kid-friendly)
    RankCategory(name: "Disney Songs", emoji: "🎵", items: [
        "Let It Go", "How Far I'll Go", "A Whole New World", "Under the Sea",
        "You've Got a Friend in Me", "Hakuna Matata", "We Don't Talk About Bruno",
        "Surface Pressure"
    ]),
    RankCategory(name: "Taylor Swift Eras", emoji: "✨", items: [
        "Fearless", "Red", "1989", "Lover",
        "Folklore", "Evermore", "Midnights", "The Tortured Poets Department"
    ]),
    RankCategory(name: "Sing-Along Songs", emoji: "🎤", items: [
        "Happy (Pharrell)", "Shake It Off", "Can't Stop the Feeling",
        "Don't Stop Believin'", "Dancing Queen", "Sweet Caroline",
        "We Will Rock You", "ABC (Jackson 5)"
    ]),

    // Animals & Nature
    RankCategory(name: "Pets to Have", emoji: "🐶", items: [
        "Dog", "Cat", "Hamster", "Bunny", "Fish",
        "Guinea Pig", "Turtle", "Parrot"
    ]),
    RankCategory(name: "Wild Animals", emoji: "🦁", items: [
        "Lion", "Dolphin", "Wolf", "Eagle", "Elephant",
        "Panda", "Tiger", "Otter", "Snow Leopard"
    ]),
    RankCategory(name: "Mythical Creatures", emoji: "🐉", items: [
        "Dragon", "Unicorn", "Phoenix", "Griffin", "Mermaid",
        "Pegasus", "Kraken", "Thunderbird"
    ]),
    RankCategory(name: "Dinosaurs", emoji: "🦕", items: [
        "T-Rex", "Triceratops", "Velociraptor", "Stegosaurus",
        "Brachiosaurus", "Pterodactyl", "Ankylosaurus", "Spinosaurus"
    ]),

    // Games & Fun
    RankCategory(name: "Video Games", emoji: "🎮", items: [
        "Minecraft", "Mario Kart", "Zelda", "Pokémon", "Roblox",
        "Animal Crossing", "Super Smash Bros", "Kirby"
    ]),
    RankCategory(name: "Board Games", emoji: "🎲", items: [
        "Monopoly", "Uno", "Clue", "Sorry!", "Candy Land",
        "Connect Four", "Jenga", "Life"
    ]),
    RankCategory(name: "Playground Games", emoji: "🏃", items: [
        "Tag", "Hide and Seek", "Four Square", "Capture the Flag",
        "Kickball", "Dodgeball", "Red Light Green Light", "Freeze Dance"
    ]),
    RankCategory(name: "Superpowers", emoji: "⚡", items: [
        "Flying", "Invisibility", "Teleportation", "Time Travel", "Mind Reading",
        "Super Strength", "Shape Shifting", "Healing"
    ]),

    // School & Hobbies
    RankCategory(name: "School Subjects", emoji: "📚", items: [
        "Art", "Music", "Gym", "Science", "Math",
        "Reading", "History", "Recess"
    ]),
    RankCategory(name: "After School Activities", emoji: "⭐", items: [
        "Soccer", "Dance", "Swimming", "Drawing", "Gymnastics",
        "Martial Arts", "Drama Club", "Coding"
    ]),
    RankCategory(name: "Art Supplies", emoji: "🎨", items: [
        "Markers", "Colored Pencils", "Watercolors", "Crayons",
        "Glitter Glue", "Clay", "Pastels", "Stickers"
    ]),

    // Sports
    RankCategory(name: "Sports to Play", emoji: "⚽", items: [
        "Soccer", "Basketball", "Swimming", "Baseball",
        "Gymnastics", "Tennis", "Skateboarding", "Volleyball"
    ]),
    RankCategory(name: "Olympic Events", emoji: "🏅", items: [
        "Gymnastics", "Track & Field", "Swimming", "Skateboarding",
        "Diving", "Volleyball", "Fencing", "Snowboarding"
    ]),

    // Imagination & Preferences
    RankCategory(name: "Places to Visit", emoji: "✈️", items: [
        "Disney World", "The Beach", "A Space Station", "The North Pole",
        "A Treehouse Village", "An Underwater City", "Tokyo", "A Chocolate Factory"
    ]),
    RankCategory(name: "If You Could Be...", emoji: "🧙", items: [
        "A Wizard", "A Pirate", "An Astronaut", "A Superhero",
        "A Dinosaur Trainer", "A Chef", "A Secret Agent", "A Time Traveler"
    ]),
    RankCategory(name: "Birthday Party Themes", emoji: "🎂", items: [
        "Pool Party", "Movie Night", "Sleepover", "Scavenger Hunt",
        "Trampoline Park", "Art Party", "Laser Tag", "Costume Party"
    ]),
    RankCategory(name: "Seasons & Holidays", emoji: "🎄", items: [
        "Summer Vacation", "Halloween", "Christmas", "Snow Days",
        "Birthday", "Spring Break", "Thanksgiving", "Fourth of July"
    ]),
    RankCategory(name: "Bedtime Stories", emoji: "📖", items: [
        "Harry Potter", "Percy Jackson", "Diary of a Wimpy Kid",
        "Dog Man", "Wings of Fire", "The Wild Robot",
        "Chronicles of Narnia", "Dork Diaries"
    ]),
    RankCategory(name: "Streaming Shows", emoji: "🖥️", items: [
        "Stranger Things", "Percy Jackson", "Wednesday", "Loki",
        "The Mandalorian", "Ghostbusters: Afterlife", "Cobra Kai", "Avatar (Netflix)"
    ]),

    // More Food & Drink
    RankCategory(name: "Boba Tea Flavors", emoji: "🧋", items: [
        "Classic Milk Tea", "Taro", "Brown Sugar", "Mango",
        "Strawberry", "Matcha", "Lychee", "Thai Tea"
    ]),
    RankCategory(name: "Fast Food Spots", emoji: "🍔", items: [
        "McDonald's", "Chick-fil-A", "Taco Bell", "Wendy's",
        "In-N-Out", "Chipotle", "Five Guys", "Raising Cane's"
    ]),
    RankCategory(name: "Spicy Snacks", emoji: "🌶️", items: [
        "Hot Cheetos", "Takis", "Spicy Ramen", "Hot Wings",
        "Jalapeño Chips", "Spicy Nacho Doritos", "Buffalo Pretzels", "Chili Lime Chips"
    ]),
    RankCategory(name: "Breakfast Cereal", emoji: "🥣", items: [
        "Froot Loops", "Lucky Charms", "Cinnamon Toast Crunch", "Frosted Flakes",
        "Cocoa Puffs", "Cap'n Crunch", "Honey Nut Cheerios", "Cookie Crisp"
    ]),
    RankCategory(name: "Cookies", emoji: "🍪", items: [
        "Chocolate Chip", "Oreo", "Snickerdoodle", "Sugar Cookie",
        "Oatmeal Raisin", "Peanut Butter", "Double Chocolate", "Macaron"
    ]),
    RankCategory(name: "Favorite Fruit", emoji: "🍓", items: [
        "Strawberry", "Watermelon", "Mango", "Grapes",
        "Banana", "Pineapple", "Blueberry", "Apple"
    ]),
    RankCategory(name: "Cold Drinks", emoji: "🥤", items: [
        "Slushie", "Lemonade", "Smoothie", "Milkshake",
        "Root Beer Float", "Hot Chocolate", "Sparkling Water", "Iced Tea"
    ]),

    // More Games
    RankCategory(name: "Roblox Games", emoji: "🟥", items: [
        "Adopt Me", "Brookhaven", "Blox Fruits", "Tower of Hell",
        "Pet Simulator", "Murder Mystery 2", "Bloxburg", "Doors"
    ]),
    RankCategory(name: "Minecraft Mobs", emoji: "🟩", items: [
        "Creeper", "Enderman", "Axolotl", "Warden",
        "Allay", "Wolf", "Villager", "Fox"
    ]),
    RankCategory(name: "Mario Characters", emoji: "🍄", items: [
        "Mario", "Luigi", "Princess Peach", "Bowser",
        "Yoshi", "Toad", "Daisy", "Wario"
    ]),
    RankCategory(name: "Pokémon", emoji: "🔴", items: [
        "Pikachu", "Charizard", "Eevee", "Mewtwo",
        "Snorlax", "Gengar", "Lucario", "Bulbasaur"
    ]),
    RankCategory(name: "Video Game Characters", emoji: "🕹️", items: [
        "Sonic", "Mario", "Link", "Kirby",
        "Steve (Minecraft)", "Pikachu", "Master Chief", "Sora"
    ]),
    RankCategory(name: "Mario Kart Items", emoji: "🏎️", items: [
        "Banana Peel", "Red Shell", "Blue Shell", "Mushroom",
        "Star", "Bullet Bill", "Lightning", "Boo"
    ]),

    // Internet & Trends
    RankCategory(name: "Kid YouTubers", emoji: "📱", items: [
        "MrBeast", "Dude Perfect", "Mark Rober", "Ryan's World",
        "DanTDM", "Unspeakable", "Preston", "LankyBox"
    ]),
    RankCategory(name: "Emojis", emoji: "😂", items: [
        "😂", "💀", "🔥", "😭",
        "🥺", "💅", "🙏", "✨"
    ]),
    RankCategory(name: "Fidget Toys", emoji: "🌀", items: [
        "Pop It", "Fidget Spinner", "Squishmallow", "Tangle",
        "Stretchy String", "Marble Mesh", "Infinity Cube", "Slime"
    ]),

    // More Animals
    RankCategory(name: "Ocean Animals", emoji: "🐠", items: [
        "Dolphin", "Shark", "Sea Turtle", "Octopus",
        "Jellyfish", "Whale", "Seahorse", "Clownfish"
    ]),
    RankCategory(name: "Baby Animals", emoji: "🐣", items: [
        "Puppy", "Kitten", "Bunny", "Duckling",
        "Penguin Chick", "Baby Panda", "Fawn", "Piglet"
    ]),
    RankCategory(name: "Bugs & Insects", emoji: "🐛", items: [
        "Butterfly", "Ladybug", "Firefly", "Bee",
        "Ant", "Dragonfly", "Grasshopper", "Caterpillar"
    ]),
    RankCategory(name: "Reptiles & Amphibians", emoji: "🦎", items: [
        "Gecko", "Chameleon", "Bearded Dragon", "Frog",
        "Turtle", "Snake", "Axolotl", "Iguana"
    ]),
    RankCategory(name: "Farm Animals", emoji: "🐄", items: [
        "Cow", "Horse", "Pig", "Chicken",
        "Goat", "Sheep", "Duck", "Llama"
    ]),

    // More Hobbies & Collecting
    RankCategory(name: "Slime Types", emoji: "🟢", items: [
        "Cloud Slime", "Butter Slime", "Glitter Slime", "Clear Slime",
        "Fluffy Slime", "Crunchy Slime", "Foam Slime", "Glow-in-the-Dark"
    ]),
    RankCategory(name: "Things to Collect", emoji: "🧸", items: [
        "Pokémon Cards", "Squishmallows", "Stickers", "Lego Sets",
        "Crystals", "Keychains", "Sneakers", "Coins"
    ]),
    RankCategory(name: "Lego Themes", emoji: "🧱", items: [
        "City", "Star Wars", "Ninjago", "Friends",
        "Harry Potter", "Technic", "Minecraft", "Marvel"
    ]),
    RankCategory(name: "Crafts to Make", emoji: "✂️", items: [
        "Friendship Bracelets", "Origami", "Painting", "Bead Art",
        "Clay Figures", "Scrapbooking", "Knitting", "DIY Slime"
    ]),

    // More Music
    RankCategory(name: "Pop Stars", emoji: "🎤", items: [
        "Taylor Swift", "Olivia Rodrigo", "Billie Eilish", "Sabrina Carpenter",
        "Ariana Grande", "Bruno Mars", "Dua Lipa", "Harry Styles"
    ]),
    RankCategory(name: "K-pop Groups", emoji: "💜", items: [
        "BTS", "BLACKPINK", "Stray Kids", "TWICE",
        "NewJeans", "SEVENTEEN", "aespa", "ENHYPEN"
    ]),

    // More Movies & TV
    RankCategory(name: "Studio Ghibli Films", emoji: "🌳", items: [
        "Spirited Away", "My Neighbor Totoro", "Ponyo", "Howl's Moving Castle",
        "Kiki's Delivery Service", "Castle in the Sky", "Princess Mononoke", "Arrietty"
    ]),
    RankCategory(name: "DreamWorks Movies", emoji: "🐲", items: [
        "Shrek", "How to Train Your Dragon", "Kung Fu Panda", "Madagascar",
        "The Bad Guys", "Trolls", "Megamind", "Puss in Boots"
    ]),
    RankCategory(name: "Anime", emoji: "🍥", items: [
        "Pokémon", "Demon Slayer", "My Hero Academia", "One Piece",
        "Spy x Family", "Dragon Ball", "Naruto", "Sonic X"
    ]),
    RankCategory(name: "Video Game Movies", emoji: "🎞️", items: [
        "The Super Mario Bros. Movie", "Sonic the Hedgehog", "Detective Pikachu",
        "A Minecraft Movie", "Wreck-It Ralph", "The Angry Birds Movie",
        "Five Nights at Freddy's", "Ralph Breaks the Internet"
    ]),

    // More Sports & Outdoors
    RankCategory(name: "Pool Activities", emoji: "🏊", items: [
        "Cannonball", "Marco Polo", "Diving for Rings", "Pool Noodle Battle",
        "Belly Flop", "Float on a Raft", "Handstand Contest", "Sharks and Minnows"
    ]),
    RankCategory(name: "Winter Activities", emoji: "❄️", items: [
        "Sledding", "Snowball Fight", "Building a Snowman", "Ice Skating",
        "Snow Angels", "Skiing", "Building a Snow Fort", "Snowboarding"
    ]),
    RankCategory(name: "Theme Park Rides", emoji: "🎢", items: [
        "Roller Coaster", "Bumper Cars", "Ferris Wheel", "Log Flume",
        "Drop Tower", "Carousel", "Teacups", "Swing Ride"
    ]),
    RankCategory(name: "NBA Players", emoji: "🏀", items: [
        "LeBron James", "Stephen Curry", "Giannis Antetokounmpo", "Luka Dončić",
        "Jayson Tatum", "Kevin Durant", "Ja Morant", "Victor Wembanyama"
    ]),
    RankCategory(name: "Soccer Stars", emoji: "⚽", items: [
        "Lionel Messi", "Cristiano Ronaldo", "Kylian Mbappé", "Erling Haaland",
        "Christian Pulisic", "Neymar", "Vini Jr.", "Sophia Smith"
    ]),

    // More Imagination & Life
    RankCategory(name: "When You Grow Up", emoji: "💼", items: [
        "YouTuber", "Game Developer", "Veterinarian", "Astronaut",
        "Pro Athlete", "Marine Biologist", "Artist", "Scientist"
    ]),
    RankCategory(name: "Dream Bedroom", emoji: "🛏️", items: [
        "Bunk Bed", "Gaming Setup", "LED Lights", "Secret Door",
        "Beanbag Chair", "Mini Fridge", "Reading Nook", "Wall of Posters"
    ]),
    RankCategory(name: "Worst Chores", emoji: "🧹", items: [
        "Taking Out Trash", "Washing Dishes", "Folding Laundry", "Cleaning Your Room",
        "Vacuuming", "Mowing the Lawn", "Walking the Dog", "Setting the Table"
    ]),
    RankCategory(name: "Best Pet to Sneak Into Class", emoji: "🐹", items: [
        "Puppy", "Kitten", "Hamster", "Bunny",
        "Parrot", "Mini Pig", "Lizard", "Goldfish"
    ]),
]

struct RankSlot: Identifiable {
    let id: Int
    var assignedItem: String?
}

@Observable
final class GameViewModel {
    var items: [String] = []
    var slots: [RankSlot] = []
    var currentIndex: Int = 0
    var currentCategory: RankCategory?
    var showingCategoryPicker = true

    var currentItem: String? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var remainingCount: Int {
        items.count - currentIndex
    }

    var filledSlotCount: Int {
        slots.filter { $0.assignedItem != nil }.count
    }

    var isGameOver: Bool {
        guard !showingCategoryPicker else { return false }
        return currentIndex >= items.count || slots.allSatisfy { $0.assignedItem != nil }
    }

    func selectCategory(_ category: RankCategory) {
        currentCategory = category
        items = category.items.shuffled()
        slots = (1...5).map { RankSlot(id: $0) }
        currentIndex = 0
        showingCategoryPicker = false
    }

    func assignToSlot(id: Int) {
        guard let item = currentItem,
              let index = slots.firstIndex(where: { $0.id == id }),
              slots[index].assignedItem == nil
        else { return }

        slots[index].assignedItem = item
        currentIndex += 1
    }

    func reset() {
        items.shuffle()
        slots = (1...5).map { RankSlot(id: $0) }
        currentIndex = 0
    }

    func backToCategories() {
        showingCategoryPicker = true
        currentCategory = nil
    }

    func startRank() {
        showingCategoryPicker = true
        currentCategory = nil
        items = []
        slots = []
        currentIndex = 0
    }
}

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var appViewModel = AppViewModel()
    @State private var faceTracker = FaceTracker()
    @State private var showingCategoryWheel = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// True only while a rank game is actively in progress (card should float).
    private var isPlayingRank: Bool {
        appViewModel.screen == .rank
            && !viewModel.showingCategoryPicker
            && !viewModel.isGameOver
    }

    var body: some View {
        ZStack {
            // Heads Up plays with the phone on the forehead facing away — the
            // selfie feed is pointless and wastes power, so suppress the camera
            // entirely for that screen. Removing the view deallocates
            // CameraUIView, which stops the capture session.
            if appViewModel.screen == .headsUp || appViewModel.screen == .ultimateTTT {
                Color.black
                    .ignoresSafeArea()
            } else {
                CameraPreviewView { reading in
                    faceTracker.foreheadPoint = reading.foreheadPoint
                    faceTracker.roll = reading.roll
                    faceTracker.faceCentersX = reading.faceCentersX
                    faceTracker.mouthOpen = reading.mouthOpen
                    faceTracker.mouthCenter = reading.mouthCenter
                    faceTracker.noseTip = reading.noseTip
                    faceTracker.yaw = reading.yaw
                    faceTracker.pitch = reading.pitch
                    faceTracker.leftEyeCenter = reading.leftEyeCenter
                    faceTracker.rightEyeCenter = reading.rightEyeCenter
                    faceTracker.mouthRect = reading.mouthRect
                    faceTracker.faceBBoxWidth = reading.faceBBoxWidth
                    faceTracker.perFaceExpressions = reading.perFaceExpressions
                }
                .ignoresSafeArea()

                Color.black.opacity(0.4)
                    .ignoresSafeArea()
            }

            switch appViewModel.screen {
            case .home:
                HomeView(
                    onSelectRank: {
                        viewModel.startRank()
                        appViewModel.openRank()
                    },
                    onSelectSpeedTap: {
                        appViewModel.openSpeedTap()
                    },
                    onSelectLaneDodge: {
                        appViewModel.openLaneDodge()
                    },
                    onSelectTugOfWar: {
                        appViewModel.openTugOfWar()
                    },
                    onSelectHeadsUp: {
                        appViewModel.openHeadsUp()
                    },
                    onSelectTicTacToe: {
                        appViewModel.openTicTacToe()
                    },
                    onSelectSimon: {
                        appViewModel.openSimon()
                    },
                    onSelectLaserEyes: {
                        appViewModel.openLaserEyes()
                    },
                    onSelectChocolateRain: {
                        appViewModel.openChocolateRain()
                    },
                    onSelectVocalGlide: {
                        appViewModel.openVocalGlide()
                    },
                    onSelectChoiceGate: {
                        appViewModel.openChoiceGate()
                    },
                    onSelectUltimateTTT: {
                        appViewModel.openUltimateTTT()
                    }
                )
            case .rank:
                if viewModel.showingCategoryPicker {
                    if !showingCategoryWheel {
                        categoryPicker
                    }
                } else {
                    gameView
                }
            case .speedTap:
                SpeedTapView(onExit: {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                })
            case .laneDodge:
                LaneDodgeView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .tugOfWar:
                TugOfWarView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .headsUp:
                HeadsUpView(onExit: {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                })
            case .ticTacToe:
                TicTacToeView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .simon:
                SimonGameView(onExit: {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                })
            case .laserEyes:
                LaserEyesView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .chocolateRain:
                ChocolateRainView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .vocalGlide:
                VocalGlideView(
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .choiceGate:
                ChoiceGateView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
            case .ultimateTTT:
                UltimateTTTView(onExit: {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                })
            }
        }
        // Forehead-tracked card lives at the top level so its coordinate space
        // matches the full-screen camera/Vision space (origin = screen top-left).
        .overlay {
            GeometryReader { geo in
                if isPlayingRank, let item = viewModel.currentItem {
                    currentItemCard(item)
                        .position(cardCenter(in: geo.size))
                        .animation(.linear(duration: 0.1), value: faceTracker.foreheadPoint)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)   // taps fall through to the slots
        }
        .overlay {
            if showingCategoryWheel {
                SpinWheelView(
                    items: allCategories.map {
                        WheelItem(id: $0.name, label: $0.name, emoji: $0.emoji)
                    },
                    onLanded: { landed in
                        guard let category = allCategories.first(where: { $0.name == landed.id }) else {
                            showingCategoryWheel = false
                            return
                        }
                        // Switch to the game view *under* the still-visible wheel,
                        // then dismiss the wheel on the next runloop tick. Mutating
                        // both the @Observable picker flag and the @State wheel flag
                        // in one frame can render a transient category-picker flash
                        // because the two observation systems don't always coalesce.
                        viewModel.selectCategory(category)
                        DispatchQueue.main.async {
                            withAnimation(.spring(duration: 0.3)) {
                                showingCategoryWheel = false
                            }
                        }
                    },
                    onCancel: {
                        showingCategoryWheel = false
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Floating card placement

    /// Center point for the floating item card: above the forehead when a face is
    /// tracked, otherwise a fixed top-center fallback so the game stays playable.
    private func cardCenter(in size: CGSize) -> CGPoint {
        let floatGap: CGFloat = 90   // lift the card above the forehead
        if let p = faceTracker.foreheadPoint {
            let clampedY = max(floatGap, p.y - floatGap)
            let clampedX = min(max(p.x, 80), size.width - 80)
            return CGPoint(x: clampedX, y: clampedY)
        }
        return CGPoint(x: size.width / 2, y: isCompact ? 120 : 150)
    }

    // MARK: - Category Picker

    private var categoryColumns: [GridItem] {
        if isCompact {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }

    private var categoryPicker: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            HStack {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Games")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button {
                    showingCategoryWheel = true
                } label: {
                    HStack(spacing: 6) {
                        Text("🎲")
                        Text("Spin for me")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 16 : 24)

            Text("What are you ranking?")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, isCompact ? 24 : 40)

            ScrollView {
                LazyVGrid(columns: categoryColumns, spacing: isCompact ? 12 : 16) {
                    ForEach(allCategories) { category in
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.selectCategory(category)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(category.emoji)
                                    .font(.system(size: isCompact ? 28 : 36))
                                Text(category.name)
                                    .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isCompact ? 14 : 20)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Game View

    private var gameView: some View {
        VStack(spacing: isCompact ? 20 : 32) {
            header
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.top, isCompact ? 12 : 20)

            Spacer()

            // Game-over card stays in the layout; the in-progress item card is
            // rendered in the forehead-tracking overlay, not here.
            if viewModel.isGameOver {
                gameOverCard
            }

            slotStack
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.bottom, isCompact ? 24 : 40)   // anchor slots toward bottom
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.backToCategories()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    if !isCompact {
                        Text("Back")
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            if let category = viewModel.currentCategory {
                Text("\(category.emoji) \(category.name)")
                    .font(isCompact ? .footnote.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Game Components

    private func currentItemCard(_ item: String) -> some View {
        VStack(spacing: 8) {
            Text(item)
                .font(.system(size: isCompact ? 30 : 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Text("\(viewModel.remainingCount - 1) more coming")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, isCompact ? 20 : 28)
        .padding(.horizontal, isCompact ? 28 : 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    private var gameOverCard: some View {
        VStack(spacing: 16) {
            Text("That's your top 5")
                .font(.system(size: isCompact ? 28 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Shuffle & redo") {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.reset()
                    }
                }
                .font(isCompact ? .body.weight(.semibold) : .title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())

                Button("New topic") {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.backToCategories()
                    }
                }
                .font(isCompact ? .body.weight(.semibold) : .title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var slotStack: some View {
        VStack(spacing: isCompact ? 10 : 16) {
            ForEach(viewModel.slots) { slot in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.assignToSlot(id: slot.id)
                    }
                } label: {
                    HStack(spacing: isCompact ? 8 : 12) {
                        Text(slotLabel(for: slot.id))
                            .font(isCompact ? .body.weight(.bold).monospacedDigit() : .title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: isCompact ? 60 : 80, alignment: .leading)

                        if let assigned = slot.assignedItem {
                            Text(assigned)
                                .font(isCompact ? .body.weight(.semibold) : .title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else if !viewModel.isGameOver {
                            Text(slotHint(for: slot.id))
                                .font(isCompact ? .subheadline : .title3)
                                .foregroundStyle(.white.opacity(0.35))
                        }

                        Spacer()
                    }
                    .padding(.vertical, isCompact ? 14 : 20)
                    .padding(.horizontal, isCompact ? 14 : 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(slot.assignedItem != nil
                                  ? Color.white.opacity(0.15)
                                  : Color.white.opacity(0.06))
                            .stroke(Color.white.opacity(slot.assignedItem != nil ? 0.3 : 0.15), lineWidth: 1)
                    )
                }
                .disabled(slot.assignedItem != nil || viewModel.isGameOver)
            }
        }
    }

    private func slotLabel(for rank: Int) -> String {
        switch rank {
        case 1: return "#1"
        case 2: return "#2"
        case 3: return "#3"
        case 4: return "#4"
        case 5: return "#5"
        default: return "#\(rank)"
        }
    }

    private func slotHint(for rank: Int) -> String {
        switch rank {
        case 1: return "favorite"
        case 5: return "least fave"
        default: return ""
        }
    }
}

#Preview {
    ContentView()
}
