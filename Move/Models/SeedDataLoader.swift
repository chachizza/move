import Foundation

struct SeedExercise: Decodable {
    let id: UUID
    let name: String
    let emoji: String
    let category: String
    let durationMinutes: Int
    let difficulty: Int
    let instructions: String?
    let isActive: Bool
}

enum SeedDataLoader {
    static func loadExercises() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "SeedExercises", withExtension: "json") else {
            print("Seed file not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let seeds = try decoder.decode([SeedExercise].self, from: data)
            return seeds.map { seed in
                Exercise(id: seed.id,
                         name: seed.name,
                         emoji: seed.emoji,
                         category: seed.category,
                         durationMinutes: seed.durationMinutes,
                         difficulty: seed.difficulty,
                         instructions: seed.instructions,
                         isActive: seed.isActive)
            }
        } catch {
            print("Failed to decode seed exercises: \(error)")
            return []
        }
    }
}
