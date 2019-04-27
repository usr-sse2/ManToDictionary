# ManToDictionary
This is a program to convert `man` pages to Apple Dictionary dictionaries. It allows to find manuals for shell commands and C functions using **Dictionary** app, **Look Up** context menu item, or **Look up & data detectors** trackpad gesture in **Terminal**, **Safari**, **TextEdit** and other applications.

![Lookup from Terminal](https://github.com/usr-sse2/ManToDictionary/raw/master/Terminal.png)

![Dictionary app](https://github.com/usr-sse2/ManToDictionary/raw/master/Dictionary.png)


### Usage
1. Create `~/Library/Dictionaries` directory, if it doesn't exist.
2. Specify all man page directories in `manDirs` array in `main.swift`
3. Compile and run the program. It will build dictionaries and install them in `~/Library/Dictionaries`.
4. Open **Dictionary** application and enable man sections in preferences:

![Dictionary Preferences](https://github.com/usr-sse2/ManToDictionary/raw/master/Dictionary%20Preferences.png)

Now you can use the dictionaries.
