import 'package:flutter/material.dart';
import 'package:projectshowcase/mvc/models/project.dart';
import 'package:projectshowcase/services/gemini_service.dart';
import 'package:projectshowcase/utils/pdf_text_extractor.dart';

class ChatWithProjectScreen extends StatefulWidget {
  final Project project;

  const ChatWithProjectScreen({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  State<ChatWithProjectScreen> createState() => _ChatWithProjectScreenState();
}

class _ChatWithProjectScreenState extends State<ChatWithProjectScreen> {
  final GeminiService _gemini = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  String? _combinedContext;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  
  // Track what sources were loaded
  bool _hasAbstract = false;
  bool _hasPdf = false;

  @override
  void initState() {
    super.initState();
    _loadAllSources();
  }

  Future<void> _loadAllSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final StringBuffer contextBuffer = StringBuffer();
    final List<String> loadedSources = [];

    try {
      // 1. Load Abstract (always available)
      contextBuffer.writeln('=== PROJECT ABSTRACT ===');
      contextBuffer.writeln(widget.project.abstract);
      contextBuffer.writeln();
      _hasAbstract = true;
      loadedSources.add('Abstract');

      // 2. Try to load PDF
      if (widget.project.pdfUrl != null && widget.project.pdfUrl!.isNotEmpty) {
        try {
          final pdfText = await PdfContentExtractor.extractFromUrl(widget.project.pdfUrl!);
          contextBuffer.writeln('=== PROJECT DOCUMENTATION (PDF) ===');
          contextBuffer.writeln(pdfText);
          contextBuffer.writeln();
          _hasPdf = true;
          loadedSources.add('PDF Documentation');
        } catch (e) {
          debugPrint('Failed to load PDF: $e');
        }
      }

      // Finalize
      setState(() {
        _combinedContext = contextBuffer.toString();
        _isLoading = false;
      });

      // Add welcome message showing what was loaded
      final sourcesText = loadedSources.join(', ');
      _addMessage(
        ChatMessage(
          text: 'Hi! I\'ve analyzed the project "${widget.project.title}".\n\n'
              '📚 Sources loaded: $sourcesText\n\n'
              'Feel free to ask me anything about this project!',
          isUser: false,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load project content: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _addMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.add(message);
    });
    
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _combinedContext == null) return;

    // Add user message
    _addMessage(ChatMessage(text: message, isUser: true));
    _messageController.clear();

    setState(() {
      _isProcessing = true;
    });

    try {
      // Stream AI response
      String aiResponse = '';
      ChatMessage aiMessage = ChatMessage(text: '', isUser: false);
      _addMessage(aiMessage);
      
      final stream = _gemini.chatWithProjectStream(
        pdfContent: _combinedContext!,
        userQuestion: message,
      );

      await for (final chunk in stream) {
        aiResponse += chunk;
        if (mounted) {
          setState(() {
            _messages[_messages.length - 1] = ChatMessage(
              text: aiResponse,
              isUser: false,
            );
          });
        }
        
        // Auto-scroll during streaming
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Project'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Project Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'By ${widget.project.authorName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages Area
          Expanded(
            child: _buildMessagesArea(),
          ),

          // Input Area
          if (!_isLoading && _error == null) _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading project content...'),
            const SizedBox(height: 8),
            Text(
              'Abstract${widget.project.pdfUrl != null ? ' • PDF' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllSources,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _ChatBubble(message: message);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  hintText: 'Ask about this project...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _isProcessing ? null : _sendMessage,
              backgroundColor: _isProcessing ? Colors.grey : Colors.deepPurple,
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              radius: 16,
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.deepPurple
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              radius: 16,
              child: Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
