package com.mybusiness

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.TextWatcher
import android.text.style.ForegroundColorSpan
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.PopupWindow
import android.widget.ListView
import android.widget.ArrayAdapter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.regex.Pattern

data class MentionUser(val id: String, val name: String)

data class MentionRange(val start: Int, val end: Int, val userId: String, val userName: String)

class MentionTextFieldPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val views = mutableMapOf<Int, MentionTextFieldView>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.mybusiness/mention_textfield")
        channel.setMethodCallHandler(this)
        
        binding.platformViewRegistry.registerViewFactory(
            "com.mybusiness/mention_textfield",
            MentionTextFieldFactory(this)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setUsers" -> {
                val viewId = call.argument<Int>("viewId")
                val usersData = call.argument<List<Map<String, String>>>("users")
                
                if (viewId != null && usersData != null) {
                    val users = usersData.map { MentionUser(it["id"] ?: "", it["name"] ?: "") }
                    views[viewId]?.setUsers(users)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "viewId and users are required", null)
                }
            }
            "requestUsers" -> {
                result.success(emptyList<Map<String, String>>())
            }
            else -> result.notImplemented()
        }
    }

    fun registerView(viewId: Int, view: MentionTextFieldView) {
        views[viewId] = view
    }

    fun unregisterView(viewId: Int) {
        views.remove(viewId)
    }

    fun notifyTextChanged(viewId: Int, text: String) {
        channel.invokeMethod("onTextChanged", mapOf("text" to text))
    }

    fun notifyTap(viewId: Int) {
        channel.invokeMethod("onTap", null)
    }
}

class MentionTextFieldFactory(private val plugin: MentionTextFieldPlugin) : 
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any> ?: emptyMap()
        return MentionTextFieldView(context, viewId, creationParams, plugin)
    }
}

class MentionTextFieldView(
    context: Context,
    private val viewId: Int,
    creationParams: Map<String, Any>,
    private val plugin: MentionTextFieldPlugin
) : PlatformView {
    
    private val editText: EditText = EditText(context)
    private var users = listOf<MentionUser>()
    private val mentions = mutableListOf<MentionRange>()
    private var mentionPopup: PopupWindow? = null
    private var queryStartPos = -1
    private var currentQuery = ""
    
    private val mentionColor: Int
    private val textColor: Int
    
    init {
        plugin.registerView(viewId, this)
        
        // Parse creation params
        val initialText = creationParams["initialText"] as? String ?: ""
        val usersData = creationParams["users"] as? List<Map<String, String>> ?: emptyList()
        users = usersData.map { MentionUser(it["id"] ?: "", it["name"] ?: "") }
        
        textColor = parseColor(creationParams["textColor"] as? String ?: "#EAEAEA")
        mentionColor = parseColor(creationParams["mentionColor"] as? String ?: "#0095FF")
        val backgroundColor = parseColor(creationParams["backgroundColor"] as? String ?: "#1E1E1E")
        val fontSize = (creationParams["fontSize"] as? Double ?: 14.0).toFloat()
        val hintText = creationParams["hintText"] as? String ?: "Digite o texto..."
        
        // Configure EditText
        editText.apply {
            setText(initialText)
            setTextColor(textColor)
            setBackgroundColor(backgroundColor)
            textSize = fontSize
            hint = hintText
            setHintTextColor(Color.parseColor("#888888"))
            setPadding(12, 12, 12, 12)
            
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        // Add text watcher
        editText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                handleTextChanged(s?.toString() ?: "")
            }
            
            override fun afterTextChanged(s: Editable?) {
                updateMentionFormatting()
            }
        })
        
        // Set initial text with mentions
        setTextWithMentions(initialText)
        
        editText.setOnClickListener {
            plugin.notifyTap(viewId)
        }
    }
    
    override fun getView(): View = editText
    
    override fun dispose() {
        plugin.unregisterView(viewId)
        mentionPopup?.dismiss()
    }
    
    fun setUsers(newUsers: List<MentionUser>) {
        users = newUsers
    }
    
    private fun handleTextChanged(text: String) {
        // Check for @ character to start mention
        val cursorPos = editText.selectionStart
        
        if (queryStartPos >= 0) {
            // Currently in mention mode
            if (cursorPos > queryStartPos) {
                val query = text.substring(queryStartPos, cursorPos)
                
                // Check if query contains space or newline (end of mention)
                if (query.contains(' ') || query.contains('\n')) {
                    hideMentionDropdown()
                    queryStartPos = -1
                } else {
                    currentQuery = query
                    showMentionDropdown(query)
                }
            }
        } else {
            // Check if @ was just typed
            if (cursorPos > 0 && text.getOrNull(cursorPos - 1) == '@') {
                queryStartPos = cursorPos
                currentQuery = ""
                showMentionDropdown("")
            }
        }
        
        // Notify Flutter
        val textWithMentions = getTextWithMentions()
        plugin.notifyTextChanged(viewId, textWithMentions)
    }
    
    private fun showMentionDropdown(query: String) {
        val filteredUsers = users.filter { 
            it.name.contains(query, ignoreCase = true) 
        }
        
        if (filteredUsers.isEmpty()) {
            hideMentionDropdown()
            return
        }
        
        // Create popup if it doesn't exist
        if (mentionPopup == null) {
            val listView = ListView(editText.context)
            mentionPopup = PopupWindow(
                listView,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                true
            )
        }
        
        val listView = mentionPopup?.contentView as? ListView
        listView?.adapter = ArrayAdapter(
            editText.context,
            android.R.layout.simple_list_item_1,
            filteredUsers.map { it.name }
        )
        
        listView?.setOnItemClickListener { _, _, position, _ ->
            insertMention(filteredUsers[position])
        }
        
        // Show popup below cursor
        mentionPopup?.showAsDropDown(editText)
    }
    
    private fun hideMentionDropdown() {
        mentionPopup?.dismiss()
    }
    
    private fun insertMention(user: MentionUser) {
        val text = editText.text.toString()
        val cursorPos = editText.selectionStart
        
        // Replace from @ to cursor with mention
        val beforeMention = text.substring(0, queryStartPos - 1)
        val afterMention = text.substring(cursorPos)
        val mention = "@[${user.name}](${user.id})"
        
        val newText = beforeMention + mention + afterMention
        editText.setText(newText)
        editText.setSelection(beforeMention.length + mention.length)
        
        // Reset query state
        queryStartPos = -1
        currentQuery = ""
        
        hideMentionDropdown()
    }
    
    private fun updateMentionFormatting() {
        val text = editText.text
        if (text !is Spannable) return
        
        // Remove existing spans
        val spans = text.getSpans(0, text.length, ForegroundColorSpan::class.java)
        spans.forEach { text.removeSpan(it) }
        
        // Find and format mentions
        val pattern = Pattern.compile("@\\[([^\\]]+)\\]\\(([^)]+)\\)")
        val matcher = pattern.matcher(text)
        
        while (matcher.find()) {
            val start = matcher.start()
            val end = matcher.end()
            text.setSpan(
                ForegroundColorSpan(mentionColor),
                start,
                end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
    }
    
    private fun getTextWithMentions(): String {
        return editText.text.toString()
    }
    
    private fun setTextWithMentions(text: String) {
        editText.setText(text)
        updateMentionFormatting()
    }
    
    private fun parseColor(hex: String): Int {
        return try {
            Color.parseColor(hex)
        } catch (e: Exception) {
            Color.parseColor("#EAEAEA")
        }
    }
}

