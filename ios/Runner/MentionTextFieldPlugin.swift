import Flutter
import UIKit

struct MentionUser {
    let id: String
    let name: String
}

struct MentionRange {
    let range: NSRange
    let userId: String
    let userName: String
}

class MentionTextFieldPlugin: NSObject, FlutterPlugin {
    static var channel: FlutterMethodChannel?
    static var views: [Int: MentionTextFieldView] = [:]
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.mybusiness/mention_textfield", binaryMessenger: registrar.messenger())
        let instance = MentionTextFieldPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        MentionTextFieldPlugin.channel = channel
        
        let factory = MentionTextFieldFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "com.mybusiness/mention_textfield")
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setUsers":
            guard let args = call.arguments as? [String: Any],
                  let viewId = args["viewId"] as? Int,
                  let usersData = args["users"] as? [[String: String]] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "viewId and users are required", details: nil))
                return
            }
            
            let users = usersData.compactMap { dict -> MentionUser? in
                guard let id = dict["id"], let name = dict["name"] else { return nil }
                return MentionUser(id: id, name: name)
            }
            
            MentionTextFieldPlugin.views[viewId]?.setUsers(users)
            result(true)
            
        case "requestUsers":
            result([])
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    static func notifyTextChanged(viewId: Int, text: String) {
        channel?.invokeMethod("onTextChanged", arguments: ["text": text])
    }
    
    static func notifyTap(viewId: Int) {
        channel?.invokeMethod("onTap", arguments: nil)
    }
}

class MentionTextFieldFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return MentionTextFieldView(frame: frame, viewId: Int(viewId), arguments: args as? [String: Any] ?? [:])
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class MentionTextFieldView: NSObject, FlutterPlatformView, UITextViewDelegate {
    private var textView: UITextView
    private var viewId: Int
    private var users: [MentionUser] = []
    private var mentions: [MentionRange] = []
    private var mentionTableView: UITableView?
    private var queryStartPos: Int = -1
    private var currentQuery: String = ""
    
    private let mentionColor: UIColor
    private let textColor: UIColor
    
    init(frame: CGRect, viewId: Int, arguments: [String: Any]) {
        self.viewId = viewId
        self.textView = UITextView(frame: frame)
        
        // Parse arguments
        let initialText = arguments["initialText"] as? String ?? ""
        let usersData = arguments["users"] as? [[String: String]] ?? []
        users = usersData.compactMap { dict -> MentionUser? in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return MentionUser(id: id, name: name)
        }
        
        textColor = Self.parseColor(arguments["textColor"] as? String ?? "#EAEAEA")
        mentionColor = Self.parseColor(arguments["mentionColor"] as? String ?? "#0095FF")
        let backgroundColor = Self.parseColor(arguments["backgroundColor"] as? String ?? "#1E1E1E")
        let fontSize = CGFloat(arguments["fontSize"] as? Double ?? 14.0)
        
        super.init()
        
        // Configure text view
        textView.delegate = self
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.font = UIFont.systemFont(ofSize: fontSize)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        // Set initial text
        setTextWithMentions(initialText)
        
        // Register view
        MentionTextFieldPlugin.views[viewId] = self
    }
    
    func view() -> UIView {
        return textView
    }
    
    func setUsers(_ newUsers: [MentionUser]) {
        users = newUsers
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        handleTextChanged()
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        // Handle cursor movement
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Check for @ character
        if text == "@" {
            queryStartPos = range.location + 1
            currentQuery = ""
            showMentionDropdown(query: "")
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func handleTextChanged() {
        let text = textView.text ?? ""
        let cursorPos = textView.selectedRange.location
        
        if queryStartPos >= 0 {
            // Currently in mention mode
            if cursorPos > queryStartPos {
                let startIndex = text.index(text.startIndex, offsetBy: queryStartPos)
                let endIndex = text.index(text.startIndex, offsetBy: cursorPos)
                let query = String(text[startIndex..<endIndex])
                
                // Check if query contains space or newline (end of mention)
                if query.contains(" ") || query.contains("\n") {
                    hideMentionDropdown()
                    queryStartPos = -1
                } else {
                    currentQuery = query
                    showMentionDropdown(query: query)
                }
            }
        }
        
        updateMentionFormatting()
        
        // Notify Flutter
        let textWithMentions = getTextWithMentions()
        MentionTextFieldPlugin.notifyTextChanged(viewId: viewId, text: textWithMentions)
    }
    
    private func showMentionDropdown(query: String) {
        let filteredUsers = users.filter { user in
            user.name.lowercased().contains(query.lowercased())
        }
        
        if filteredUsers.isEmpty {
            hideMentionDropdown()
            return
        }
        
        // Create table view if it doesn't exist
        if mentionTableView == nil {
            let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            mentionTableView = tableView
            
            // Add to superview
            if let superview = textView.superview {
                superview.addSubview(tableView)
                
                // Position below text view
                tableView.frame.origin = CGPoint(
                    x: textView.frame.origin.x,
                    y: textView.frame.origin.y + textView.frame.height
                )
            }
        }
        
        // TODO: Implement table view data source and delegate
        // For now, we'll skip the visual dropdown
    }
    
    private func hideMentionDropdown() {
        mentionTableView?.removeFromSuperview()
        mentionTableView = nil
    }
    
    private func insertMention(_ user: MentionUser) {
        let text = textView.text ?? ""
        let cursorPos = textView.selectedRange.location
        
        // Replace from @ to cursor with mention
        let beforeMention = String(text.prefix(queryStartPos - 1))
        let afterMention = String(text.suffix(text.count - cursorPos))
        let mention = "@[\(user.name)](\(user.id))"
        
        let newText = beforeMention + mention + afterMention
        textView.text = newText
        
        // Set cursor position
        let newCursorPos = beforeMention.count + mention.count
        textView.selectedRange = NSRange(location: newCursorPos, length: 0)
        
        // Reset query state
        queryStartPos = -1
        currentQuery = ""
        
        hideMentionDropdown()
        updateMentionFormatting()
    }
    
    private func updateMentionFormatting() {
        guard let text = textView.text else { return }
        
        let attributedString = NSMutableAttributedString(string: text)
        
        // Set default attributes
        attributedString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.font, value: textView.font ?? UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: text.count))
        
        // Find and format mentions
        let pattern = "@\\[([^\\]]+)\\]\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: mentionColor, range: match.range)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: textView.font?.pointSize ?? 14), range: match.range)
            }
        }
        
        // Preserve cursor position
        let selectedRange = textView.selectedRange
        textView.attributedText = attributedString
        textView.selectedRange = selectedRange
    }
    
    private func getTextWithMentions() -> String {
        return textView.text ?? ""
    }
    
    private func setTextWithMentions(_ text: String) {
        textView.text = text
        updateMentionFormatting()
    }
    
    private static func parseColor(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

