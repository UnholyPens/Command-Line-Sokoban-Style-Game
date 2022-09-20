# Command Line Sokoban Style Game
A Sokoban-style puzzle game that is played through the command line interface. 

This is a relatively simple game that is played through the command line, programmed in x86 assembly, and compiled using Make. It was initially made as a final project for an Assembly Language course, built upon some structural code given to me by my instructor, but I've since continued working on it as a sort of personal challenge. 


Controls are listed at the top of the terminal, although pressing "h" for help/hints currently doesn't work.

Game objects are color coded, for ease of use. For example, all lever-related objects are blue, and all key-related objects are yellow.


Objects are as follows:

R: Rock - A pushable object that can also be used to activate a pressure plate.

K: Key - These are used to open key doors.

P: Pressure Plate - When all pressure plates have been depressed all pressure plate doors will open. The player is not heavy enough to activate these, so a rock must be used instead

S: Stairs - Interact with these to progress to the next level. 

L: Lever - Interact wth this to open all of the lever doors in the level.

T: Wall - Immovable, and impassable.

B: Button - A button door will only open once all buttons have been activated. Currently, 'b' is inactive, and 'B' is active.

#: Door - Simply a door blocking one's path. They are color coded to objects that pair with them, and will open depending on the requirements for each door.
