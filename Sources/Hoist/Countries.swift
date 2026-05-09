import Foundation

/// One row in the country picker. `code` is ISO 3166-1 alpha-2; `flag` is
/// derived from the code (regional-indicator scalars), and `timeZone` is
/// an IANA identifier used by the optional time-display feature.
///
/// For countries that span multiple zones (US, RU, CA, AU, BR, MX, KZ,
/// ID), we pick the *capital city's* zone — most useful default and the
/// least surprising behaviour for someone tracking "what time is it in
/// the US" without further qualification.
struct Country: Identifiable, Hashable {
    let code: String
    let name: String
    let timeZone: String

    var id: String { code }
    var flag: String { Country.emojiFlag(for: code) }

    /// Build the regional-indicator emoji for an ISO alpha-2 code.
    /// The two regional-indicator code points (U+1F1E6…U+1F1FF) sit at
    /// offset 0x1F1A5 above ASCII 'A'…'Z'; concatenating two of them
    /// produces the country flag glyph macOS renders in the menu bar.
    static func emojiFlag(for code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 2,
              upper.unicodeScalars.allSatisfy({ ("A"..."Z").contains(Character($0)) })
        else { return "🏳️" }
        let base: UInt32 = 0x1F1A5
        var result = ""
        for scalar in upper.unicodeScalars {
            guard let s = Unicode.Scalar(base + scalar.value) else { return "🏳️" }
            result.unicodeScalars.append(s)
        }
        return result
    }

    static func find(code: String) -> Country? {
        let needle = code.uppercased()
        return all.first { $0.code == needle }
    }

    /// Default selection if UserDefaults is empty or holds an unknown code.
    static let fallback = Country(code: "IN", name: "India", timeZone: "Asia/Kolkata")

    /// ISO 3166-1 alpha-2 subset (~110 of ~249), alphabetical by name.
    /// Time zones are IANA identifiers — verified via `TimeZone(identifier:)`.
    static let all: [Country] = [
        Country(code: "AF", name: "Afghanistan",            timeZone: "Asia/Kabul"),
        Country(code: "AL", name: "Albania",                timeZone: "Europe/Tirane"),
        Country(code: "DZ", name: "Algeria",                timeZone: "Africa/Algiers"),
        Country(code: "AR", name: "Argentina",              timeZone: "America/Argentina/Buenos_Aires"),
        Country(code: "AM", name: "Armenia",                timeZone: "Asia/Yerevan"),
        Country(code: "AU", name: "Australia",              timeZone: "Australia/Sydney"),
        Country(code: "AT", name: "Austria",                timeZone: "Europe/Vienna"),
        Country(code: "AZ", name: "Azerbaijan",             timeZone: "Asia/Baku"),
        Country(code: "BH", name: "Bahrain",                timeZone: "Asia/Bahrain"),
        Country(code: "BD", name: "Bangladesh",             timeZone: "Asia/Dhaka"),
        Country(code: "BY", name: "Belarus",                timeZone: "Europe/Minsk"),
        Country(code: "BE", name: "Belgium",                timeZone: "Europe/Brussels"),
        Country(code: "BO", name: "Bolivia",                timeZone: "America/La_Paz"),
        Country(code: "BA", name: "Bosnia and Herzegovina", timeZone: "Europe/Sarajevo"),
        Country(code: "BR", name: "Brazil",                 timeZone: "America/Sao_Paulo"),
        Country(code: "BG", name: "Bulgaria",               timeZone: "Europe/Sofia"),
        Country(code: "KH", name: "Cambodia",               timeZone: "Asia/Phnom_Penh"),
        Country(code: "CM", name: "Cameroon",               timeZone: "Africa/Douala"),
        Country(code: "CA", name: "Canada",                 timeZone: "America/Toronto"),
        Country(code: "CL", name: "Chile",                  timeZone: "America/Santiago"),
        Country(code: "CN", name: "China",                  timeZone: "Asia/Shanghai"),
        Country(code: "CO", name: "Colombia",               timeZone: "America/Bogota"),
        Country(code: "CR", name: "Costa Rica",             timeZone: "America/Costa_Rica"),
        Country(code: "HR", name: "Croatia",                timeZone: "Europe/Zagreb"),
        Country(code: "CU", name: "Cuba",                   timeZone: "America/Havana"),
        Country(code: "CY", name: "Cyprus",                 timeZone: "Asia/Nicosia"),
        Country(code: "CZ", name: "Czechia",                timeZone: "Europe/Prague"),
        Country(code: "DK", name: "Denmark",                timeZone: "Europe/Copenhagen"),
        Country(code: "DO", name: "Dominican Republic",     timeZone: "America/Santo_Domingo"),
        Country(code: "EC", name: "Ecuador",                timeZone: "America/Guayaquil"),
        Country(code: "EG", name: "Egypt",                  timeZone: "Africa/Cairo"),
        Country(code: "EE", name: "Estonia",                timeZone: "Europe/Tallinn"),
        Country(code: "ET", name: "Ethiopia",               timeZone: "Africa/Addis_Ababa"),
        Country(code: "FI", name: "Finland",                timeZone: "Europe/Helsinki"),
        Country(code: "FR", name: "France",                 timeZone: "Europe/Paris"),
        Country(code: "GE", name: "Georgia",                timeZone: "Asia/Tbilisi"),
        Country(code: "DE", name: "Germany",                timeZone: "Europe/Berlin"),
        Country(code: "GH", name: "Ghana",                  timeZone: "Africa/Accra"),
        Country(code: "GR", name: "Greece",                 timeZone: "Europe/Athens"),
        Country(code: "GT", name: "Guatemala",              timeZone: "America/Guatemala"),
        Country(code: "HN", name: "Honduras",               timeZone: "America/Tegucigalpa"),
        Country(code: "HK", name: "Hong Kong",              timeZone: "Asia/Hong_Kong"),
        Country(code: "HU", name: "Hungary",                timeZone: "Europe/Budapest"),
        Country(code: "IS", name: "Iceland",                timeZone: "Atlantic/Reykjavik"),
        Country(code: "IN", name: "India",                  timeZone: "Asia/Kolkata"),
        Country(code: "ID", name: "Indonesia",              timeZone: "Asia/Jakarta"),
        Country(code: "IR", name: "Iran",                   timeZone: "Asia/Tehran"),
        Country(code: "IQ", name: "Iraq",                   timeZone: "Asia/Baghdad"),
        Country(code: "IE", name: "Ireland",                timeZone: "Europe/Dublin"),
        Country(code: "IL", name: "Israel",                 timeZone: "Asia/Jerusalem"),
        Country(code: "IT", name: "Italy",                  timeZone: "Europe/Rome"),
        Country(code: "JM", name: "Jamaica",                timeZone: "America/Jamaica"),
        Country(code: "JP", name: "Japan",                  timeZone: "Asia/Tokyo"),
        Country(code: "JO", name: "Jordan",                 timeZone: "Asia/Amman"),
        Country(code: "KZ", name: "Kazakhstan",             timeZone: "Asia/Almaty"),
        Country(code: "KE", name: "Kenya",                  timeZone: "Africa/Nairobi"),
        Country(code: "KW", name: "Kuwait",                 timeZone: "Asia/Kuwait"),
        Country(code: "LV", name: "Latvia",                 timeZone: "Europe/Riga"),
        Country(code: "LB", name: "Lebanon",                timeZone: "Asia/Beirut"),
        Country(code: "LY", name: "Libya",                  timeZone: "Africa/Tripoli"),
        Country(code: "LT", name: "Lithuania",              timeZone: "Europe/Vilnius"),
        Country(code: "LU", name: "Luxembourg",             timeZone: "Europe/Luxembourg"),
        Country(code: "MY", name: "Malaysia",               timeZone: "Asia/Kuala_Lumpur"),
        Country(code: "MT", name: "Malta",                  timeZone: "Europe/Malta"),
        Country(code: "MX", name: "Mexico",                 timeZone: "America/Mexico_City"),
        Country(code: "MD", name: "Moldova",                timeZone: "Europe/Chisinau"),
        Country(code: "MN", name: "Mongolia",               timeZone: "Asia/Ulaanbaatar"),
        Country(code: "MA", name: "Morocco",                timeZone: "Africa/Casablanca"),
        Country(code: "MM", name: "Myanmar",                timeZone: "Asia/Yangon"),
        Country(code: "NP", name: "Nepal",                  timeZone: "Asia/Kathmandu"),
        Country(code: "NL", name: "Netherlands",            timeZone: "Europe/Amsterdam"),
        Country(code: "NZ", name: "New Zealand",            timeZone: "Pacific/Auckland"),
        Country(code: "NI", name: "Nicaragua",              timeZone: "America/Managua"),
        Country(code: "NG", name: "Nigeria",                timeZone: "Africa/Lagos"),
        Country(code: "KP", name: "North Korea",            timeZone: "Asia/Pyongyang"),
        Country(code: "MK", name: "North Macedonia",        timeZone: "Europe/Skopje"),
        Country(code: "NO", name: "Norway",                 timeZone: "Europe/Oslo"),
        Country(code: "OM", name: "Oman",                   timeZone: "Asia/Muscat"),
        Country(code: "PK", name: "Pakistan",               timeZone: "Asia/Karachi"),
        Country(code: "PA", name: "Panama",                 timeZone: "America/Panama"),
        Country(code: "PY", name: "Paraguay",               timeZone: "America/Asuncion"),
        Country(code: "PE", name: "Peru",                   timeZone: "America/Lima"),
        Country(code: "PH", name: "Philippines",            timeZone: "Asia/Manila"),
        Country(code: "PL", name: "Poland",                 timeZone: "Europe/Warsaw"),
        Country(code: "PT", name: "Portugal",               timeZone: "Europe/Lisbon"),
        Country(code: "QA", name: "Qatar",                  timeZone: "Asia/Qatar"),
        Country(code: "RO", name: "Romania",                timeZone: "Europe/Bucharest"),
        Country(code: "RU", name: "Russia",                 timeZone: "Europe/Moscow"),
        Country(code: "SA", name: "Saudi Arabia",           timeZone: "Asia/Riyadh"),
        Country(code: "RS", name: "Serbia",                 timeZone: "Europe/Belgrade"),
        Country(code: "SG", name: "Singapore",              timeZone: "Asia/Singapore"),
        Country(code: "SK", name: "Slovakia",               timeZone: "Europe/Bratislava"),
        Country(code: "SI", name: "Slovenia",               timeZone: "Europe/Ljubljana"),
        Country(code: "ZA", name: "South Africa",           timeZone: "Africa/Johannesburg"),
        Country(code: "KR", name: "South Korea",            timeZone: "Asia/Seoul"),
        Country(code: "ES", name: "Spain",                  timeZone: "Europe/Madrid"),
        Country(code: "LK", name: "Sri Lanka",              timeZone: "Asia/Colombo"),
        Country(code: "SD", name: "Sudan",                  timeZone: "Africa/Khartoum"),
        Country(code: "SE", name: "Sweden",                 timeZone: "Europe/Stockholm"),
        Country(code: "CH", name: "Switzerland",            timeZone: "Europe/Zurich"),
        Country(code: "SY", name: "Syria",                  timeZone: "Asia/Damascus"),
        Country(code: "TW", name: "Taiwan",                 timeZone: "Asia/Taipei"),
        Country(code: "TZ", name: "Tanzania",               timeZone: "Africa/Dar_es_Salaam"),
        Country(code: "TH", name: "Thailand",               timeZone: "Asia/Bangkok"),
        Country(code: "TN", name: "Tunisia",                timeZone: "Africa/Tunis"),
        Country(code: "TR", name: "Türkiye",                timeZone: "Europe/Istanbul"),
        Country(code: "UA", name: "Ukraine",                timeZone: "Europe/Kyiv"),
        Country(code: "AE", name: "United Arab Emirates",   timeZone: "Asia/Dubai"),
        Country(code: "GB", name: "United Kingdom",         timeZone: "Europe/London"),
        Country(code: "US", name: "United States",          timeZone: "America/New_York"),
        Country(code: "UY", name: "Uruguay",                timeZone: "America/Montevideo"),
        Country(code: "UZ", name: "Uzbekistan",             timeZone: "Asia/Tashkent"),
        Country(code: "VE", name: "Venezuela",              timeZone: "America/Caracas"),
        Country(code: "VN", name: "Vietnam",                timeZone: "Asia/Ho_Chi_Minh"),
        Country(code: "YE", name: "Yemen",                  timeZone: "Asia/Aden"),
        Country(code: "ZM", name: "Zambia",                 timeZone: "Africa/Lusaka"),
        Country(code: "ZW", name: "Zimbabwe",               timeZone: "Africa/Harare"),
    ]
}
