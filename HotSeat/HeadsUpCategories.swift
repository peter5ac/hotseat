import Foundation

struct HeadsUpCategory: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let items: [String]
}

let headsUpCategories: [HeadsUpCategory] = [
    HeadsUpCategory(name: "Family Members", emoji: "👨‍👩‍👧‍👦", items: [
        "Peter", "Guy", "Kate", "Audrey", "Vince", "Bluebelle", "Jackie", "Berkley",
        "Harry", "RieRie", "Grampy", "Grammie", "Pa", "Uncle Jimmy", "Fuffa",
        "Little Guy", "Garrison", "Aunt Karen", "Uncle Guy", "Andre", "Steve",
        "Crystal", "Max", "Layla", "Noah", "Nana Sullivan", "Papa Sullivan"
    ]),
    HeadsUpCategory(name: "90s Cartoons", emoji: "📺", items: [
        "Rugrats", "Doug", "Hey Arnold!", "Animaniacs", "Pinky and the Brain",
        "The Powerpuff Girls", "Dexter's Laboratory", "Johnny Bravo", "Cow and Chicken",
        "Recess", "Arthur", "The Magic School Bus", "Pokémon", "Digimon", "Sailor Moon",
        "Batman: The Animated Series", "X-Men", "Spider-Man", "DuckTales", "TaleSpin",
        "Gargoyles", "Tiny Toon Adventures", "Rocko's Modern Life", "CatDog", "Aaahh!!! Real Monsters",
        "The Ren & Stimpy Show", "The Wild Thornberrys", "SpongeBob SquarePants", "Courage the Cowardly Dog",
        "Ed, Edd n Eddy", "Bear in the Big Blue House", "Blue's Clues"
    ]),
    HeadsUpCategory(name: "90s Movies", emoji: "🎬", items: [
        "Toy Story", "The Lion King", "Aladdin", "Jurassic Park", "Home Alone",
        "Beauty and the Beast", "Mrs. Doubtfire", "Jumanji", "Space Jam", "Toy Story 2",
        "A Bug's Life", "Mulan", "Hercules", "Tarzan", "The Iron Giant", "Matilda",
        "Casper", "Free Willy", "Babe", "George of the Jungle", "Flubber", "The Sandlot",
        "Cool Runnings", "Honey, I Shrunk the Kids", "The Mighty Ducks", "Antz",
        "James and the Giant Peach", "Anastasia", "The Prince of Egypt", "Stuart Little",
        "Men in Black", "Independence Day"
    ]),
    HeadsUpCategory(name: "Pixar Movies", emoji: "💡", items: [
        "Toy Story", "A Bug's Life", "Toy Story 2", "Monsters, Inc.", "Finding Nemo",
        "The Incredibles", "Cars", "Ratatouille", "WALL-E", "Up", "Toy Story 3",
        "Cars 2", "Brave", "Monsters University", "Inside Out", "The Good Dinosaur",
        "Finding Dory", "Cars 3", "Coco", "Incredibles 2", "Toy Story 4", "Onward",
        "Soul", "Luca", "Turning Red", "Lightyear", "Elemental", "Inside Out 2",
        "Up House", "Dory", "Lightning McQueen", "Mike Wazowski"
    ]),
    HeadsUpCategory(name: "Netflix Shows", emoji: "🍿", items: [
        "Stranger Things", "Wednesday", "Cobra Kai", "The Mandalorian", "Avatar: The Last Airbender",
        "One Piece", "Heartstopper", "Outer Banks", "The Witcher", "Lockwood & Co.",
        "Geek Girl", "The Umbrella Academy", "Sweet Tooth", "Enola Holmes", "The Babysitters Club",
        "A Series of Unfortunate Events", "Carmen Sandiego", "Hilda", "She-Ra and the Princesses of Power",
        "The Dragon Prince", "Kipo and the Age of Wonderbeasts", "Spirit Riding Free", "Gabby's Dollhouse",
        "CoComelon", "Boss Baby", "Trollhunters", "Green Eggs and Ham", "My Little Pony",
        "Pokémon", "Sonic Prime", "Captain Underpants", "The Last Kids on Earth"
    ]),
    HeadsUpCategory(name: "Dog Breeds", emoji: "🐶", items: [
        "Labrador Retriever", "Golden Retriever", "German Shepherd", "Bulldog", "Poodle",
        "Beagle", "Rottweiler", "Dachshund", "Corgi", "Husky", "Chihuahua", "Pug",
        "Boxer", "Great Dane", "Doberman", "Border Collie", "Australian Shepherd",
        "Shih Tzu", "Pomeranian", "Cocker Spaniel", "Bernese Mountain Dog", "Saint Bernard",
        "Dalmatian", "Jack Russell Terrier", "Yorkshire Terrier", "Maltese", "Samoyed",
        "Akita", "Basset Hound", "Newfoundland", "Greyhound", "Cavalier King Charles Spaniel"
    ]),
    HeadsUpCategory(name: "Famous Actors", emoji: "🎭", items: [
        "Tom Hanks", "Dwayne Johnson", "Will Smith", "Jennifer Lawrence", "Zendaya",
        "Tom Holland", "Robert Downey Jr.", "Chris Evans", "Chris Hemsworth", "Scarlett Johansson",
        "Ryan Reynolds", "Jim Carrey", "Eddie Murphy", "Jack Black", "Kevin Hart",
        "Emma Watson", "Daniel Radcliffe", "Adam Sandler", "Steve Carell", "Anne Hathaway",
        "Millie Bobby Brown", "Finn Wolfhard", "Jacob Tremblay", "Jaden Smith", "Angelina Jolie",
        "Johnny Depp", "Leonardo DiCaprio", "Morgan Freeman", "Samuel L. Jackson", "Robin Williams",
        "Ben Stiller", "Melissa McCarthy"
    ]),
    HeadsUpCategory(name: "Historical Figures", emoji: "🏛️", items: [
        "George Washington", "Abraham Lincoln", "Martin Luther King Jr.", "Albert Einstein",
        "Isaac Newton", "Leonardo da Vinci", "Cleopatra", "Julius Caesar", "Napoleon Bonaparte",
        "Benjamin Franklin", "Thomas Edison", "Nikola Tesla", "Marie Curie", "Rosa Parks",
        "Harriet Tubman", "Amelia Earhart", "Christopher Columbus", "Neil Armstrong",
        "Gandhi", "Nelson Mandela", "Anne Frank", "Joan of Arc", "Galileo Galilei",
        "Alexander the Great", "Queen Elizabeth I", "King Tut", "Wright Brothers",
        "Helen Keller", "Walt Disney", "Pablo Picasso", "William Shakespeare", "Theodore Roosevelt"
    ]),
    HeadsUpCategory(name: "Emojis", emoji: "😂", items: [
        "Laughing Crying", "Skull", "Fire", "Heart Eyes", "Thumbs Up", "Poop",
        "Crying Face", "Smiling Face", "Sunglasses Face", "Thinking Face", "Rolling Eyes",
        "Folded Hands", "Clapping Hands", "Flexed Bicep", "Party Popper", "Birthday Cake",
        "Pizza", "Taco", "Soccer Ball", "Basketball", "Rocket", "Star", "Rainbow",
        "Unicorn", "Dog Face", "Cat Face", "Monkey Covering Eyes", "Ghost", "Alien",
        "Robot", "Sparkles", "Hundred Points"
    ]),
    HeadsUpCategory(name: "Classic Fiction", emoji: "📚", items: [
        "Charlotte's Web", "The Cat in the Hat", "Where the Wild Things Are", "Matilda",
        "Charlie and the Chocolate Factory", "The BFG", "James and the Giant Peach",
        "Alice in Wonderland", "Peter Pan", "The Wizard of Oz", "The Secret Garden",
        "Anne of Green Gables", "Little Women", "Treasure Island", "The Jungle Book",
        "Winnie the Pooh", "The Chronicles of Narnia", "The Hobbit", "Black Beauty",
        "Pinocchio", "The Velveteen Rabbit", "Stuart Little", "The Little Prince",
        "A Wrinkle in Time", "The Giving Tree", "Goodnight Moon", "The Very Hungry Caterpillar",
        "Green Eggs and Ham", "The Lorax", "Oh, the Places You'll Go!", "Holes", "Bridge to Terabithia"
    ]),
    HeadsUpCategory(name: "YouTubers", emoji: "▶️", items: [
        "MrBeast", "Mark Rober", "Dude Perfect", "Ryan's World", "DanTDM", "Unspeakable",
        "Preston", "LankyBox", "SSundee", "Aphmau", "PewDiePie", "Jacksepticeye",
        "Markiplier", "Dream", "GeorgeNotFound", "Sapnap", "TommyInnit", "Technoblade",
        "KSI", "Logan Paul", "Jake Paul", "Emma Chamberlain", "Stokes Twins", "Brent Rivera",
        "Lazarbeam", "Typical Gamer", "FGTeeV", "CaptainSparklez", "Vat19", "Smarter Every Day",
        "The Slow Mo Guys", "Veritasium"
    ]),
    HeadsUpCategory(name: "WWE", emoji: "🤼", items: [
        "John Cena", "The Rock", "Stone Cold Steve Austin", "Hulk Hogan", "Undertaker",
        "Triple H", "Roman Reigns", "Seth Rollins", "Brock Lesnar", "Randy Orton",
        "Rey Mysterio", "Becky Lynch", "Charlotte Flair", "Ronda Rousey", "Bianca Belair",
        "Cody Rhodes", "Drew McIntyre", "AJ Styles", "Kevin Owens", "Sami Zayn",
        "Big Show", "Kane", "Edge", "Batista", "Shawn Michaels", "Bret Hart",
        "Ric Flair", "Macho Man Randy Savage", "Andre the Giant", "Sasha Banks",
        "Logan Paul", "Braun Strowman"
    ]),
    HeadsUpCategory(name: "Harry Potter Characters", emoji: "⚡", items: [
        "Harry Potter", "Hermione Granger", "Ron Weasley", "Albus Dumbledore", "Severus Snape",
        "Lord Voldemort", "Rubeus Hagrid", "Draco Malfoy", "Sirius Black", "Remus Lupin",
        "Minerva McGonagall", "Ginny Weasley", "Fred Weasley", "George Weasley", "Neville Longbottom",
        "Luna Lovegood", "Bellatrix Lestrange", "Dobby", "Professor Quirrell", "Cedric Diggory",
        "Cho Chang", "Cornelius Fudge", "Dolores Umbridge", "Mad-Eye Moody", "Lucius Malfoy",
        "Molly Weasley", "Arthur Weasley", "Nymphadora Tonks", "Gilderoy Lockhart", "Peter Pettigrew",
        "Fleur Delacour", "Viktor Krum"
    ]),
    HeadsUpCategory(name: "Percy Jackson Characters", emoji: "🔱", items: [
        "Percy Jackson", "Annabeth Chase", "Grover Underwood", "Luke Castellan", "Chiron",
        "Tyson", "Clarisse La Rue", "Thalia Grace", "Nico di Angelo", "Rachel Elizabeth Dare",
        "Poseidon", "Zeus", "Hades", "Athena", "Ares", "Apollo", "Artemis", "Hermes",
        "Dionysus", "Kronos", "Medusa", "The Minotaur", "Bianca di Angelo", "Mr. D",
        "Sally Jackson", "Gabe Ugliano", "Charon", "Hephaestus", "Aphrodite", "Demeter",
        "Hestia", "Polyphemus"
    ]),
    HeadsUpCategory(name: "Actions & Charades", emoji: "🤹", items: [
        "Brushing your teeth", "Tying your shoes", "Riding a bike", "Swimming", "Dancing",
        "Playing guitar", "Cooking", "Sleeping", "Sneezing", "Laughing", "Crying",
        "Jumping rope", "Throwing a ball", "Driving a car", "Flying a kite", "Fishing",
        "Painting", "Reading a book", "Eating spaghetti", "Brushing your hair", "Yawning",
        "Tiptoeing", "Boxing", "Skateboarding", "Climbing a ladder", "Hula hooping",
        "Playing piano", "Building a sandcastle", "Blowing bubbles", "Doing jumping jacks",
        "Walking a dog", "Putting on socks"
    ]),
    HeadsUpCategory(name: "Animals", emoji: "🦁", items: [
        "Lion", "Tiger", "Elephant", "Giraffe", "Zebra", "Monkey", "Gorilla", "Bear",
        "Wolf", "Fox", "Deer", "Rabbit", "Kangaroo", "Koala", "Panda", "Penguin",
        "Dolphin", "Whale", "Shark", "Octopus", "Crocodile", "Snake", "Frog", "Owl",
        "Eagle", "Parrot", "Flamingo", "Cheetah", "Hippo", "Rhino", "Camel", "Sloth"
    ]),
    HeadsUpCategory(name: "Disney Animated Movies", emoji: "🏰", items: [
        "The Lion King", "Frozen", "Moana", "Tangled", "Encanto", "Aladdin",
        "The Little Mermaid", "Beauty and the Beast", "Cinderella", "Snow White",
        "Sleeping Beauty", "Mulan", "Hercules", "Tarzan", "Pocahontas", "Bambi",
        "Dumbo", "Pinocchio", "Peter Pan", "The Jungle Book", "Lilo & Stitch",
        "Big Hero 6", "Zootopia", "Wreck-It Ralph", "Frozen 2", "Raya and the Last Dragon",
        "The Princess and the Frog", "Wish", "101 Dalmatians", "Alice in Wonderland",
        "The Aristocats", "Robin Hood"
    ]),
    HeadsUpCategory(name: "Pokémon", emoji: "🔴", items: [
        "Pikachu", "Charizard", "Bulbasaur", "Squirtle", "Charmander", "Eevee", "Mewtwo",
        "Mew", "Snorlax", "Gengar", "Lucario", "Jigglypuff", "Meowth", "Psyduck",
        "Magikarp", "Gyarados", "Dragonite", "Lapras", "Vaporeon", "Jolteon", "Flareon",
        "Ditto", "Onix", "Machamp", "Alakazam", "Greninja", "Lugia", "Ho-Oh",
        "Rayquaza", "Garchomp", "Gardevoir", "Sylveon"
    ]),
    HeadsUpCategory(name: "Video Games", emoji: "🎮", items: [
        "Minecraft", "Fortnite", "Roblox", "Mario Kart", "Super Mario Bros.", "The Legend of Zelda",
        "Pokémon", "Animal Crossing", "Super Smash Bros.", "Kirby", "Sonic the Hedgehog",
        "Among Us", "Fall Guys", "Splatoon", "Pac-Man", "Tetris", "Donkey Kong",
        "Metroid", "Star Fox", "Overwatch", "Rocket League", "Stardew Valley", "Terraria",
        "Just Dance", "Lego Star Wars", "Crash Bandicoot", "Spyro", "Cuphead",
        "Plants vs. Zombies", "Subway Surfers", "Geometry Dash", "Five Nights at Freddy's"
    ]),
    HeadsUpCategory(name: "Superheroes", emoji: "🦸", items: [
        "Spider-Man", "Iron Man", "Captain America", "Thor", "Hulk", "Black Panther",
        "Black Widow", "Doctor Strange", "Ant-Man", "Captain Marvel", "Hawkeye",
        "Scarlet Witch", "Wolverine", "Deadpool", "Batman", "Superman", "Wonder Woman",
        "The Flash", "Aquaman", "Green Lantern", "Robin", "Cyborg", "Shazam",
        "Groot", "Rocket Raccoon", "Star-Lord", "Miles Morales", "Spider-Gwen",
        "Nightwing", "Supergirl", "Green Arrow", "Ms. Marvel"
    ]),
    HeadsUpCategory(name: "Mythical Creatures", emoji: "🐉", items: [
        "Dragon", "Unicorn", "Phoenix", "Griffin", "Mermaid", "Pegasus", "Kraken",
        "Centaur", "Minotaur", "Cyclops", "Medusa", "Werewolf", "Vampire", "Fairy",
        "Goblin", "Troll", "Ogre", "Elf", "Dwarf", "Gnome", "Yeti", "Bigfoot",
        "Loch Ness Monster", "Chimera", "Hydra", "Cerberus", "Sphinx", "Basilisk",
        "Leprechaun", "Genie", "Banshee", "Kelpie"
    ]),
    HeadsUpCategory(name: "Pop Stars", emoji: "🎤", items: [
        "Taylor Swift", "Olivia Rodrigo", "Billie Eilish", "Sabrina Carpenter", "Ariana Grande",
        "Bruno Mars", "Dua Lipa", "Harry Styles", "Justin Bieber", "Ed Sheeran",
        "Beyoncé", "Rihanna", "Katy Perry", "Lady Gaga", "Selena Gomez", "Shawn Mendes",
        "Charlie Puth", "Doja Cat", "SZA", "The Weeknd", "Post Malone", "Drake",
        "Adele", "Miley Cyrus", "Camila Cabello", "Halsey", "Lizzo", "Bad Bunny",
        "Michael Jackson", "Madonna", "Elvis Presley", "Whitney Houston"
    ]),
    HeadsUpCategory(name: "Ghibli & Anime Characters", emoji: "🍥", items: [
        "Totoro", "Chihiro", "No-Face", "Howl", "Kiki", "Ponyo", "Princess Mononoke",
        "Calcifer", "Jiji", "Naruto", "Sasuke", "Goku", "Vegeta", "Luffy", "Zoro",
        "Pikachu", "Ash Ketchum", "Tanjiro", "Nezuko", "Deku", "Bakugo", "All Might",
        "Eren Yeager", "Levi", "Sailor Moon", "Edward Elric", "Inuyasha", "Light Yagami",
        "Saitama", "Spike Spiegel", "Astro Boy", "Anya Forger"
    ]),
    HeadsUpCategory(name: "Marvel Characters", emoji: "🛡️", items: [
        "Iron Man", "Captain America", "Thor", "Hulk", "Black Widow", "Hawkeye",
        "Spider-Man", "Black Panther", "Doctor Strange", "Scarlet Witch", "Vision",
        "Ant-Man", "The Wasp", "Captain Marvel", "Star-Lord", "Gamora", "Groot",
        "Rocket Raccoon", "Drax", "Loki", "Thanos", "Nick Fury", "Wolverine",
        "Deadpool", "Storm", "Cyclops", "Jean Grey", "Professor X", "Magneto",
        "Venom", "Green Goblin", "Nebula"
    ]),
    HeadsUpCategory(name: "Star Wars Characters", emoji: "⭐", items: [
        "Luke Skywalker", "Darth Vader", "Princess Leia", "Han Solo", "Chewbacca",
        "Yoda", "Obi-Wan Kenobi", "R2-D2", "C-3PO", "Darth Maul", "Emperor Palpatine",
        "Boba Fett", "Jabba the Hutt", "Lando Calrissian", "Padmé Amidala", "Anakin Skywalker",
        "Mace Windu", "Qui-Gon Jinn", "Jar Jar Binks", "Rey", "Finn", "Poe Dameron",
        "Kylo Ren", "BB-8", "General Grievous", "Count Dooku", "The Mandalorian",
        "Grogu", "Ahsoka Tano", "Stormtrooper", "Jango Fett", "Ewok"
    ]),
    HeadsUpCategory(name: "Minecraft", emoji: "🟩", items: [
        "Creeper", "Enderman", "Zombie", "Skeleton", "Spider", "Steve", "Alex",
        "Villager", "Iron Golem", "Wither", "Ender Dragon", "Ghast", "Blaze",
        "Slime", "Pig", "Cow", "Chicken", "Sheep", "Wolf", "Cat", "Fox", "Axolotl",
        "Warden", "Allay", "Piglin", "Diamond", "Emerald", "TNT", "Pickaxe",
        "Crafting Table", "Redstone", "Bedrock"
    ]),
    HeadsUpCategory(name: "Roblox Games", emoji: "🟥", items: [
        "Adopt Me", "Brookhaven", "Blox Fruits", "Tower of Hell", "Pet Simulator X",
        "Murder Mystery 2", "Bloxburg", "Doors", "Arsenal", "Jailbreak", "Piggy",
        "Natural Disaster Survival", "MeepCity", "Royale High", "Work at a Pizza Place",
        "Theme Park Tycoon", "Mega Mansion Tycoon", "Build A Boat for Treasure",
        "Flee the Facility", "Tower Defense Simulator", "Dress to Impress", "Rainbow Friends",
        "Da Hood", "Pls Donate", "Evade", "Sharkbite", "Speed Run 4", "Hide and Seek Extreme",
        "Epic Minigames", "Super Bomb Survival", "Welcome to Bloxburg", "Slap Battles"
    ]),
    HeadsUpCategory(name: "Sports & Athletes", emoji: "🏅", items: [
        "Soccer", "Basketball", "Baseball", "Football", "Tennis", "Golf", "Hockey",
        "Swimming", "Gymnastics", "Volleyball", "Skateboarding", "Surfing", "Boxing",
        "Wrestling", "Track and Field", "LeBron James", "Stephen Curry", "Lionel Messi",
        "Cristiano Ronaldo", "Serena Williams", "Simone Biles", "Tom Brady", "Patrick Mahomes",
        "Shaquille O'Neal", "Michael Jordan", "Usain Bolt", "Tiger Woods", "Shohei Ohtani",
        "Caitlin Clark", "Megan Rapinoe", "Kobe Bryant", "Wayne Gretzky"
    ]),
    HeadsUpCategory(name: "Jobs & Professions", emoji: "💼", items: [
        "Doctor", "Teacher", "Firefighter", "Police Officer", "Chef", "Astronaut",
        "Pilot", "Veterinarian", "Dentist", "Nurse", "Farmer", "Scientist", "Artist",
        "Musician", "Actor", "Athlete", "Lawyer", "Judge", "Engineer", "Architect",
        "Plumber", "Electrician", "Carpenter", "Mail Carrier", "Librarian", "Zookeeper",
        "Lifeguard", "Magician", "Clown", "Detective", "Photographer", "Baker"
    ]),
    HeadsUpCategory(name: "Foods & Snacks", emoji: "🍕", items: [
        "Pizza", "Hamburger", "Hot Dog", "Tacos", "Spaghetti", "Sushi", "French Fries",
        "Chicken Nuggets", "Mac and Cheese", "Grilled Cheese", "Pancakes", "Waffles",
        "Ice Cream", "Donut", "Cupcake", "Cookies", "Popcorn", "Pretzel", "Nachos",
        "Burrito", "Ramen", "Dumplings", "Pancake", "Cotton Candy", "Cheeseburger",
        "Apple", "Banana", "Watermelon", "Strawberry", "Pineapple", "Broccoli", "Carrot"
    ]),
    HeadsUpCategory(name: "Ocean Animals", emoji: "🐠", items: [
        "Dolphin", "Shark", "Whale", "Octopus", "Sea Turtle", "Jellyfish", "Seahorse",
        "Clownfish", "Starfish", "Crab", "Lobster", "Stingray", "Eel", "Pufferfish",
        "Swordfish", "Manta Ray", "Hammerhead Shark", "Great White Shark", "Orca",
        "Narwhal", "Walrus", "Seal", "Sea Lion", "Penguin", "Squid", "Hermit Crab",
        "Anglerfish", "Blue Whale", "Manatee", "Coral", "Sea Otter", "Barracuda"
    ]),
    HeadsUpCategory(name: "Dinosaurs", emoji: "🦕", items: [
        "Tyrannosaurus Rex", "Triceratops", "Velociraptor", "Stegosaurus", "Brachiosaurus",
        "Pterodactyl", "Ankylosaurus", "Spinosaurus", "Diplodocus", "Allosaurus",
        "Brontosaurus", "Parasaurolophus", "Iguanodon", "Compsognathus", "Gallimimus",
        "Dilophosaurus", "Carnotaurus", "Giganotosaurus", "Pachycephalosaurus", "Apatosaurus",
        "Megalodon", "Plesiosaur", "Mosasaurus", "Archaeopteryx", "Protoceratops",
        "Oviraptor", "Therizinosaurus", "Microraptor", "Baryonyx", "Deinonychus",
        "Edmontosaurus", "Styracosaurus"
    ]),
    HeadsUpCategory(name: "Disney Villains", emoji: "😈", items: [
        "Maleficent", "Ursula", "Scar", "Jafar", "Cruella de Vil", "Hades", "Captain Hook",
        "Gaston", "The Evil Queen", "Lady Tremaine", "Mother Gothel", "Yzma", "Shere Khan",
        "The Queen of Hearts", "Dr. Facilier", "Hans", "Frollo", "Governor Ratcliffe",
        "Madame Medusa", "Prince John", "Shan Yu", "Clayton", "Sid", "Lotso",
        "Randall", "Te Kā", "King Candy", "Hopper", "Stinky Pete", "Ernesto de la Cruz",
        "Bowler Hat Guy", "Davy Jones"
    ]),
    HeadsUpCategory(name: "Holidays & Seasons", emoji: "🎄", items: [
        "Christmas", "Halloween", "Thanksgiving", "Easter", "New Year's Eve",
        "Valentine's Day", "Fourth of July", "St. Patrick's Day", "Hanukkah",
        "Birthday", "Summer", "Winter", "Spring", "Fall", "Snow Day", "Spring Break",
        "Summer Vacation", "Mother's Day", "Father's Day", "Labor Day", "Memorial Day",
        "April Fools' Day", "Earth Day", "Cinco de Mayo", "Mardi Gras", "Diwali",
        "Lunar New Year", "Groundhog Day", "Black Friday", "Trick-or-Treating",
        "Back to School", "Pumpkin Patch"
    ]),
]
