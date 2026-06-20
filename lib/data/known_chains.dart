/// Normalizes a restaurant/chain name for fuzzy matching: lowercases, strips
/// punctuation (apostrophes, &, -, etc.) and collapses whitespace, so
/// "McDonald's" and "mcdonalds" compare equal.
String normalizeChain(String input) {
  final lower = input.toLowerCase();
  // Drop apostrophes so "mcdonald's" -> "mcdonalds"; turn other punctuation
  // into spaces so "noodles & company" -> "noodles company".
  final noApostrophe = lower.replaceAll(RegExp(r"['’`]"), '');
  final stripped = noApostrophe.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A robust list of well-known chains so a chain can be recognized even the
/// first time it's added (before you have any of your own data to match).
const List<String> kKnownChains = [
  // Burgers / fast food
  "McDonald's", 'Burger King', "Wendy's", 'Five Guys', 'Shake Shack',
  'In-N-Out', 'In-N-Out Burger', 'Whataburger', "Culver's", 'Sonic',
  'Sonic Drive-In', 'Checkers', "Carl's Jr", 'Hardee', 'Jack in the Box',
  'White Castle', 'Smashburger', 'BurgerFi', 'Fuddruckers', 'Steak n Shake',
  'A&W', 'Krystal', 'Habit Burger',
  // Chicken
  'KFC', 'Chick-fil-A', 'Popeyes', 'Raising Cane', "Raising Cane's",
  'Wingstop', 'Buffalo Wild Wings', 'Zaxby', "Zaxby's", 'Bojangles',
  "Church's Chicken", 'El Pollo Loco', 'Dave', "Dave's Hot Chicken",
  'PDQ', 'Slim Chickens', 'Wingstop',
  // Mexican / Tex-Mex
  'Chipotle', 'Taco Bell', 'Qdoba', 'Moe', "Moe's Southwest Grill",
  'Del Taco', 'Taco Cabana', 'Chronic Tacos', 'Rubio', 'On The Border',
  'Chuy', 'Torchy', "Torchy's Tacos",
  // Sandwiches / subs / delis
  'Subway', "Jersey Mike's", 'Jimmy John', "Jimmy John's", 'Firehouse Subs',
  'Jersey Mikes', 'Quiznos', 'Potbelly', 'Which Wich', 'Capriotti',
  'Penn Station', 'Schlotzsky', 'Cousins Subs', 'Mr. Sub',
  // Pizza
  "Domino's", 'Pizza Hut', "Papa John's", 'Little Caesars', 'Marco',
  "Marco's Pizza", 'Papa Murphy', 'California Pizza Kitchen', 'Blaze Pizza',
  'MOD Pizza', "Mellow Mushroom", "Round Table Pizza", "Sbarro",
  'Cicis', "Cici's Pizza",
  // Fast casual / healthy / bowls
  'Panera', 'Panera Bread', 'Sweetgreen', 'Cava', 'Chopt', 'Just Salad',
  'Panda Express', 'Pei Wei', 'Noodles & Company', "McAlister's Deli",
  'Tropical Smoothie', 'Smoothie King', 'Jamba', 'Jamba Juice', 'Freshii',
  'Dig', 'Tender Greens', 'Pokeworks', 'Poke Bowl',
  // Coffee / bakery / donuts / dessert
  'Starbucks', 'Dunkin', "Dunkin' Donuts", 'Tim Hortons', "Peet's Coffee",
  'Caribou Coffee', 'Dutch Bros', 'Krispy Kreme', 'Auntie Anne',
  'Cinnabon', 'Einstein Bros', 'Panera', 'Crumbl', 'Crumbl Cookies',
  'Insomnia Cookies', 'Nothing Bundt Cakes', 'Cold Stone', 'Cold Stone Creamery',
  'Baskin-Robbins', 'Dairy Queen', 'Ben & Jerry', 'Haagen-Dazs',
  'Menchie', 'Pinkberry', 'Jeni', 'Rita',
  // Casual / sit-down dining
  'Olive Garden', 'Cheesecake Factory', "Applebee's", "Chili's", 'IHOP',
  "Denny's", "TGI Friday's", 'Red Lobster', 'Outback Steakhouse',
  'Texas Roadhouse', 'LongHorn Steakhouse', 'Cracker Barrel', 'Buffalo Wild Wings',
  "Ruby Tuesday", "Carrabba's", 'Bonefish Grill', 'P.F. Chang',
  'PF Changs', 'BJ', "BJ's Restaurant", 'Yard House', 'Red Robin',
  'Cheddar', "Cheddar's", 'The Capital Grille', 'Maggiano',
  'Waffle House', 'First Watch', 'Bob Evans', 'Perkins',
  // Asian
  'Panda Express', 'Pei Wei', 'Pick Up Stix', 'Teriyaki Madness',
  'Sarku Japan', 'Genghis Grill',
  // Global
  'Nando', "Nando's", 'Pret a Manger', 'Greggs', 'Wagamama', 'Five Guys',
  'Wahlburgers',
];
