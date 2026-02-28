import Foundation

enum VehicleData {
    static let makeModels: [String: [String]] = [
        "Acura": ["ILX", "Integra", "MDX", "NSX", "RDX", "RLX", "TLX"],
        "Alfa Romeo": ["Giulia", "Stelvio", "Tonale"],
        "Audi": ["A3", "A4", "A5", "A6", "A7", "A8", "e-tron", "e-tron GT", "Q3", "Q4 e-tron", "Q5", "Q7", "Q8", "RS5", "RS7", "S4", "S5", "TT"],
        "BMW": ["2 Series", "3 Series", "4 Series", "5 Series", "7 Series", "8 Series", "i4", "i5", "i7", "iX", "M3", "M4", "M5", "X1", "X2", "X3", "X4", "X5", "X6", "X7", "Z4"],
        "Buick": ["Enclave", "Encore", "Encore GX", "Envision", "Envista"],
        "Cadillac": ["CT4", "CT5", "Escalade", "Escalade ESV", "LYRIQ", "XT4", "XT5", "XT6"],
        "Chevrolet": ["Blazer", "Bolt EUV", "Bolt EV", "Camaro", "Colorado", "Corvette", "Equinox", "Malibu", "Silverado 1500", "Silverado 2500HD", "Suburban", "Tahoe", "Trailblazer", "Traverse", "Trax"],
        "Chrysler": ["300", "Pacifica", "Voyager"],
        "Dodge": ["Challenger", "Charger", "Durango", "Hornet"],
        "Ford": ["Bronco", "Bronco Sport", "Edge", "Escape", "Expedition", "Explorer", "F-150", "F-150 Lightning", "Maverick", "Mustang", "Mustang Mach-E", "Ranger"],
        "Genesis": ["Electrified G80", "Electrified GV70", "G70", "G80", "G90", "GV60", "GV70", "GV80"],
        "GMC": ["Acadia", "Canyon", "Hummer EV", "Sierra 1500", "Sierra 2500HD", "Terrain", "Yukon", "Yukon XL"],
        "Honda": ["Accord", "Civic", "CR-V", "HR-V", "Odyssey", "Passport", "Pilot", "Prologue", "Ridgeline"],
        "Hyundai": ["Elantra", "Ioniq 5", "Ioniq 6", "Kona", "Palisade", "Santa Cruz", "Santa Fe", "Sonata", "Tucson", "Venue"],
        "Infiniti": ["Q50", "Q60", "QX50", "QX55", "QX60", "QX80"],
        "Jaguar": ["E-PACE", "F-PACE", "F-TYPE", "I-PACE", "XF"],
        "Jeep": ["Compass", "Gladiator", "Grand Cherokee", "Grand Cherokee L", "Grand Wagoneer", "Renegade", "Wagoneer", "Wrangler"],
        "Kia": ["Carnival", "EV6", "EV9", "Forte", "K5", "Niro", "Rio", "Seltos", "Sorento", "Soul", "Sportage", "Stinger", "Telluride"],
        "Land Rover": ["Defender", "Discovery", "Discovery Sport", "Range Rover", "Range Rover Evoque", "Range Rover Sport", "Range Rover Velar"],
        "Lexus": ["ES", "GX", "IS", "LC", "LS", "LX", "NX", "RC", "RX", "RZ", "TX", "UX"],
        "Lincoln": ["Aviator", "Corsair", "Nautilus", "Navigator"],
        "Mazda": ["CX-30", "CX-5", "CX-50", "CX-70", "CX-90", "Mazda3", "MX-5 Miata", "MX-30"],
        "Mercedes-Benz": ["A-Class", "C-Class", "CLA", "CLE", "E-Class", "EQB", "EQE", "EQS", "G-Class", "GLA", "GLB", "GLC", "GLE", "GLS", "S-Class"],
        "MINI": ["Clubman", "Convertible", "Countryman", "Hardtop 2 Door", "Hardtop 4 Door"],
        "Mitsubishi": ["Eclipse Cross", "Mirage", "Outlander", "Outlander Sport"],
        "Nissan": ["Altima", "Ariya", "Frontier", "Kicks", "LEAF", "Maxima", "Murano", "Pathfinder", "Rogue", "Sentra", "Titan", "Versa", "Z"],
        "Porsche": ["718 Boxster", "718 Cayman", "911", "Cayenne", "Macan", "Panamera", "Taycan"],
        "Ram": ["1500", "2500", "3500", "ProMaster"],
        "Rivian": ["R1S", "R1T"],
        "Subaru": ["Ascent", "BRZ", "Crosstrek", "Forester", "Impreza", "Legacy", "Outback", "Solterra", "WRX"],
        "Tesla": ["Model 3", "Model S", "Model X", "Model Y", "Cybertruck"],
        "Toyota": ["4Runner", "bZ4X", "Camry", "Corolla", "Corolla Cross", "Crown", "GR86", "GR Corolla", "GR Supra", "Grand Highlander", "Highlander", "Land Cruiser", "Prius", "RAV4", "Sequoia", "Tacoma", "Tundra", "Venza"],
        "Volkswagen": ["Atlas", "Atlas Cross Sport", "Golf GTI", "Golf R", "ID.4", "ID.Buzz", "Jetta", "Taos", "Tiguan"],
        "Volvo": ["C40 Recharge", "S60", "S90", "V60", "V90", "XC40", "XC40 Recharge", "XC60", "XC90"],
    ]

    static var makes: [String] {
        makeModels.keys.sorted()
    }

    static func models(for make: String) -> [String] {
        makeModels[make] ?? []
    }
}
