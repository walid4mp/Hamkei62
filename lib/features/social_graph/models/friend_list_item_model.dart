import 'package:socialnova/features/auth/data/models/user_data.dart';

class FriendListItemModel {
  final UserData user;
  final String friendshipId;
  const FriendListItemModel({required this.user, required this.friendshipId});
}
