import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import '../members/member_widgets.dart';
import '../ui/app_theme.dart';
import 'chat.dart';

/// One conversation in the chats list: the peer's photo, name, a preview of
/// the last message, and an unread indicator.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final unread = conversation.hasUnread;
    final preview = _previewText();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: MemberPhoto(
                  member: peer,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.displayName ?? 'Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(
                              16,
                              weight: unread ? 800 : 700,
                            ),
                          ),
                        ),
                        if (conversation.lastMessageAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _shortTime(conversation.lastMessageAt!),
                            style: jakarta(
                              12,
                              weight: unread ? 700 : 500,
                              color: unread ? AppColors.teal : AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(
                              13,
                              weight: unread ? 700 : 400,
                              color: unread ? AppColors.ink : AppColors.muted,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          _UnreadDot(count: conversation.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText() {
    final body = conversation.lastMessageBody;
    if (body == null || body.trim().isEmpty) {
      return 'Say hello to ${conversation.peer.displayName ?? 'your match'}';
    }
    return conversation.lastMessageMine ? 'You: $body' : body;
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: const BoxDecoration(
        color: AppColors.teal,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(11)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: jakarta(12, weight: 800, color: Colors.white),
      ),
    );
  }
}

/// One message in the thread: the member's own messages sit on the right in
/// teal; the other person's on the left in a light card.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.showSeen = false,
  });

  final Message message;
  final bool mine;

  /// Show a "Seen" receipt under this (the member's latest) message.
  final bool showSeen;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.teal : AppColors.mist,
                borderRadius: radius,
                border: mine
                    ? null
                    : const Border.fromBorderSide(
                        BorderSide(color: AppColors.border),
                      ),
              ),
              child: Text(
                message.body,
                style: jakarta(
                  15,
                  height: 1.4,
                  color: mine ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        if (showSeen)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text(
              'Seen',
              style: jakarta(11, weight: 600, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

/// Short relative time for the chats list ("now", "5m", "3h", "2d", or a date).
String _shortTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${when.day}/${when.month}';
}
