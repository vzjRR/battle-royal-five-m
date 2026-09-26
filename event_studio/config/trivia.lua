-- EVENT STUDIO — trivia question sets (server only; answers never leave the server before reveal)
-- Multiple choice: { q = 'text', answers = { 'a', 'b', 'c', 'd' }, correct = 2 }
-- Numeric (closest wins): { q = 'text', numeric = true, answer = 1998 }

Config.Trivia = {
    general = {
        { q = 'How many sides does a hexagon have?', answers = { '5', '6', '7', '8' }, correct = 2 },
        { q = 'Which planet is known as the Red Planet?', answers = { 'Venus', 'Jupiter', 'Mars', 'Mercury' }, correct = 3 },
        { q = 'What is the chemical symbol for gold?', answers = { 'Go', 'Gd', 'Au', 'Ag' }, correct = 3 },
        { q = 'How many minutes are in a day?', numeric = true, answer = 1440 },
        { q = 'Which ocean is the largest?', answers = { 'Atlantic', 'Indian', 'Arctic', 'Pacific' }, correct = 4 },
        { q = 'What is 12 × 12?', answers = { '124', '144', '164', '132' }, correct = 2 },
        { q = 'Which gas do plants absorb from the air?', answers = { 'Oxygen', 'Nitrogen', 'Carbon dioxide', 'Helium' }, correct = 3 },
        { q = 'How many continents are there?', answers = { '5', '6', '7', '8' }, correct = 3 },
        { q = 'In what year did the first person walk on the Moon?', numeric = true, answer = 1969 },
        { q = 'Which is the fastest land animal?', answers = { 'Lion', 'Cheetah', 'Horse', 'Pronghorn' }, correct = 2 },
        { q = 'What is the boiling point of water at sea level in °C?', numeric = true, answer = 100 },
        { q = 'Which instrument has 88 keys?', answers = { 'Organ', 'Accordion', 'Piano', 'Harp' }, correct = 3 },
    },
    memory = {
        { memory = { '🔴', '🔵', '🟢', '🟡' }, showSeconds = 4, q = 'Which order did you see?' },
        { memory = { 'CAR', 'BOAT', 'PLANE', 'BIKE' }, showSeconds = 4, q = 'Which order did you see?' },
        { memory = { '7', '3', '9', '1', '5' }, showSeconds = 5, q = 'Which number sequence was shown?' },
        { memory = { '▲', '●', '■', '◆', '★' }, showSeconds = 5, q = 'Which order did you see?' },
        { memory = { 'NORTH', 'EAST', 'SOUTH', 'WEST' }, showSeconds = 3, q = 'Which order did you see?' },
    },
    cars = {
        { q = 'How many wheels does a standard motorcycle have?', answers = { '1', '2', '3', '4' }, correct = 2 },
        { q = 'What does "RPM" stand for?', answers = { 'Rounds per mile', 'Revolutions per minute', 'Rate per meter', 'Rotations per mile' }, correct = 2 },
        { q = 'Which fuel do most Formula-style race cars use?', answers = { 'Diesel', 'Petrol / gasoline', 'Hydrogen', 'LPG' }, correct = 2 },
        { q = 'What part converts linear piston motion into rotation?', answers = { 'Camshaft', 'Crankshaft', 'Driveshaft', 'Axle' }, correct = 2 },
    },
}
