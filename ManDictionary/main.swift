import Cocoa
import CoreFoundation

class AttributedCharacter {
    let value : UInt8
    let bold : Bool
    let understrike : Bool
    init(value : UInt8, bold : Bool, understrike : Bool) {
        self.value = value
        self.bold = bold
        self.understrike = understrike
    }
    private func understrike(_ str : String) -> String {
        if understrike {
            return "<u>\(str)</u>"
        }
        return str
    }
    private func bold(_ str : String) -> String {
        if bold {
            return "<b>\(str)</b>"
        }
        return str
    }

    var escapedString : String {
        get {
            let string = String(bytes: [value], encoding: String.Encoding.isoLatin1)!
            if self.value == 0x0a {
                return "<br/>"
            }
            return bold(understrike(CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, string as CFString, nil)! as String))
        }
    }
}

struct FileOutputStream: TextOutputStream {
    let fileHandle : FileHandle

    init(path : String) {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        fileHandle = FileHandle(forWritingAtPath: path)!
    }

    func closeFile() {
        fileHandle.closeFile()
    }

    mutating func write(_ string: String) {
        fileHandle.write(string.data(using: String.Encoding.utf8)!)
    }
}

func makeXml(paths : [String], outputFile : String) {
    var stream = FileOutputStream(path: outputFile)
    var ids = Set<String>()
    print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", to: &stream)
    print("<d:dictionary xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:d=\"http://www.apple.com/DTDs/DictionaryService-1.0.rng\">", to: &stream)
    let fileManager = FileManager.default
    do {
        for section in paths {
            if !fileManager.fileExists(atPath: section) {
                continue
            }
            for file in try fileManager.contentsOfDirectory(atPath: section) {
                let name = file.split(separator: ".").dropLast().joined(separator: ".")
                let sectionNumber = file.split(separator: ".").last!
                let id = "\(name)(\(sectionNumber))"
                let (inserted, _ ) = ids.insert(id)
                if inserted {
                    print("<d:entry id=\"\(id)\" d:title=\"\(name)\">", to: &stream)

                    print("<d:index d:value=\"\(name)\"/>", to: &stream)
                    print("<d:index d:value=\"\(name)(\(sectionNumber))\"/>", to: &stream)

                    print("<pre>", to: &stream)
                    let pipe = Pipe()
                    let process = Process()
                    process.launchPath = "/usr/bin/man"
                    process.arguments = ["\(section)/\(file)"]
                    process.standardOutput = pipe
                    process.launch()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    var newData = [AttributedCharacter]()
                    var i = 0
                    while i < data.count {
                        if data[i] == 0x08 {
                            if newData.count > 0 && i + 1 < data.count {
                                let last = newData.last!.value
                                newData.removeLast(1)
                                newData.append(AttributedCharacter(value: data[i + 1], bold: last == data[i + 1], understrike: last == 0x5f && data[i + 1] != 0x5f))
                                i += 1
                            }
                        }
                        else {
                            newData.append(AttributedCharacter(value: data[i], bold: false, understrike: false))
                        }
                        i += 1
                    }
                    pipe.fileHandleForReading.closeFile()
                    pipe.fileHandleForWriting.closeFile()
                    print(newData.map({$0.escapedString}).joined()
                        .replacingOccurrences(of: "</b><b>", with: "")
                        .replacingOccurrences(of: "</s><s>", with: "")
                        //.replacingOccurrences(of: "-<br/>", with: "") // there are spaces; man by itself doesn't handle such case
                        , to: &stream)
                    print("</pre>", to: &stream)

                    print("</d:entry>", to: &stream)
                }
            }
        }
    }
    catch let error as NSError {
        print("Ooops! Something went wrong: \(error)")
    }
    print("</d:dictionary>", to: &stream)
    stream.closeFile()
}

let manDirs = ["/usr/share/man", "/usr/local/share/man", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/share/man/"]
var manSections = Set<String>()
let fileManager = FileManager.default
for manDir in manDirs {
    if !fileManager.fileExists(atPath: manDir) {
        continue
    }
    for section in try! fileManager.contentsOfDirectory(atPath: manDir).filter({$0.starts(with: "man")}) {
        manSections.insert(section)
    }
}

let sectionList = Array(manSections.sorted())
DispatchQueue.concurrentPerform(iterations: sectionList.count) { (index) in
    let section = sectionList[index]
    print("Processing section \(section)")
    try! fileManager.createDirectory(atPath: section, withIntermediateDirectories: false, attributes: nil)
    makeXml(paths: manDirs.map({"\($0)/\(section)"}), outputFile: "\(section)/dictionary.xml")
    let infoPlist = NSMutableDictionary(contentsOfFile: "Info.plist")!
    infoPlist[kCFBundleNameKey!] = "Man Section \(section.replacingOccurrences(of: "man", with: ""))"
    infoPlist.write(toFile: "\(section)/Info.plist", atomically: false)
    try! fileManager.copyItem(atPath: "Dictionary.css", toPath: "\(section)/Dictionary.css")
    var makefile = "DICT_NAME = \(section)"
    makefile.append(try! String(contentsOfFile: "Makefile"))
    try! makefile.write(toFile: "\(section)/Makefile", atomically: false, encoding: String.Encoding.utf8)
    let task = Process()
    task.launchPath = "/usr/bin/make"
    task.arguments = ["all", "install"]
    task.currentDirectoryPath = section
    task.launch()
    task.waitUntilExit()
    print("")
}
