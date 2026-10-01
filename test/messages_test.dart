import 'package:blockverse/features/messages/domain/chat_info.dart';
import 'package:blockverse/features/messages/domain/conversation_summary.dart';
import 'package:blockverse/features/messages/domain/message.dart';
import 'package:flutter_test/flutter_test.dart';

Message _msg(String id, int minute, {String content = 'hi', DateTime? deleted}) => Message(
      id: id,
      conversationId: 'c1',
      senderId: 'u1',
      content: content,
      createdAt: DateTime.utc(2026, 7, 1, 10, minute),
      deletedAt: deleted,
    );

void main() {
  test('upsertMessage inserts newest first and dedupes the realtime echo', () {
    var list = <Message>[_msg('a', 1), _msg('b', 2)]..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    list = upsertMessage(list, _msg('c', 3));
    expect(list.map((m) => m.id), ['c', 'b', 'a']);

    list = upsertMessage(list, _msg('c', 3)); // echo of our own insert
    expect(list.length, 3);

    list = upsertMessage(list, _msg('b', 2, content: '', deleted: DateTime.utc(2026, 7, 1, 11)));
    expect(list[1].isDeleted, isTrue);
    expect(list.length, 3);
  });

  test('Message.fromMap tolerates missing optional columns', () {
    final m = Message.fromMap({
      'id': 'm1', 'conversation_id': 'c1', 'sender_id': 'u1',
      'created_at': '2026-07-01T10:00:00.123456+00:00',
    });
    expect(m.content, '');
    expect(m.isEdited, isFalse);
    expect(m.hasMedia, isFalse);
  });

  Map<String, dynamic> row({bool group = false, String? content, String? sender, bool media = false, bool deleted = false}) => {
        'id': 'c1', 'is_group': group, 'title': group ? 'Builders' : null,
        'last_message_at': '2026-07-01T10:00:00Z', 'unread_count': 2, 'member_count': 2,
        'last_content': content, 'last_sender_id': sender,
        'last_has_media': media, 'last_deleted': deleted,
        'other_user_id': 'u2', 'other_username': 'alex', 'other_display_name': null,
      };

  test('ConversationSummary title and preview', () {
    final dm = ConversationSummary.fromMap(row(content: 'yo', sender: 'u2'));
    expect(dm.displayTitle, 'alex');
    expect(dm.preview('me'), 'yo');
    expect(dm.preview('u2'), 'You: yo');

    expect(ConversationSummary.fromMap(row(group: true)).displayTitle, 'Builders');
    expect(ConversationSummary.fromMap(row()).preview('me'), 'No messages yet');
    expect(ConversationSummary.fromMap(row(content: '', sender: 'u2', media: true)).preview('me'), 'Photo');
    expect(ConversationSummary.fromMap(row(content: '', sender: 'me', deleted: true)).preview('me'),
        'You: Message deleted');
  });

  test('ChatInfo read receipts', () {
    ChatMember member(String id, DateTime read) => ChatMember(
        userId: id, role: 'member', username: id, displayName: id, lastReadAt: read);
    final sent = DateTime.utc(2026, 7, 1, 10, 5);
    var info = ChatInfo(
      conversationId: 'c1',
      isGroup: true,
      title: 'G',
      members: {
        'me': member('me', sent),
        'a': member('a', DateTime.utc(2026, 7, 1, 10, 0)),
        'b': member('b', DateTime.utc(2026, 7, 1, 10, 9)),
      },
    );
    expect(info.readersOf(sent, 'me'), 1);
    info = info.withMemberRead('a', DateTime.utc(2026, 7, 1, 10, 6));
    expect(info.readersOf(sent, 'me'), 2);
    expect(info.titleFor('me'), 'G');
  });
}
