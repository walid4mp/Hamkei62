/// Lightweight data models for SocialNova v9.
class UserM {
  UserM(this.j);
  final Map<String, dynamic> j;

  String get id => '${j['id'] ?? ''}';
  String get username => '${j['username'] ?? ''}';
  String get displayName => '${j['displayName'] ?? ''}';
  String get avatarUrl => '${j['avatarUrl'] ?? ''}';
  String get coverUrl => '${j['coverUrl'] ?? ''}';
  String get bio => '${j['bio'] ?? ''}';
  String get website => '${j['website'] ?? ''}';
  String get location => '${j['location'] ?? ''}';
  String get gender => '${j['gender'] ?? ''}';
  String get birthDate => '${j['birthDate'] ?? ''}';
  String get tier => '${j['verificationTier'] ?? (j['isVerified'] == true ? 'NORMAL' : 'NONE')}';
  bool get isVerified => j['isVerified'] == true || (j['verificationTier'] != null && j['verificationTier'] != 'NONE');
  bool get isPrivate => j['isPrivate'] == true;
  bool get followingMe => j['followingMe'] == true || j['followedByMe'] == true;
  bool get isMe => j['isMe'] == true;
  bool get isLocked => j['isLocked'] == true;
  bool get followRequested => j['followRequested'] == true;
  bool get hasActiveStory => j['hasActiveStory'] == true;
  int? get followers => j['followers'] == null ? null : (j['followers'] as num).toInt();
  int? get following => j['following'] == null ? null : (j['following'] as num).toInt();
  int? get posts => j['posts'] == null ? null : (j['posts'] as num).toInt();
  int get rawFollowers => ((j['rawFollowers'] ?? j['followers'] ?? 0) as num).toInt();
  int get rawFollowing => ((j['rawFollowing'] ?? j['following'] ?? 0) as num).toInt();
  int get rawPosts => ((j['rawPosts'] ?? j['posts'] ?? 0) as num).toInt();
}

class PostM {
  PostM(this.j);
  final Map<String, dynamic> j;

  String get id => '${j['id'] ?? ''}';
  String get caption => '${j['caption'] ?? ''}';
  String get mediaUrl => '${j['mediaUrl'] ?? ''}';
  String get type => '${j['type'] ?? 'TEXT'}';
  String get musicTitle => '${j['musicTitle'] ?? ''}';
  String get musicUrl => '${j['musicUrl'] ?? ''}';
  String get title => '${j['title'] ?? ''}';
  int get rotationDegrees => ((j['rotationDegrees'] ?? 0) as num).toInt();
  String get overlayText => '${j['overlayText'] ?? ''}';
  String get overlayEmoji => '${j['overlayEmoji'] ?? ''}';
  String get overlayImageUrl => '${j['overlayImageUrl'] ?? ''}';
  String get createdAt => '${j['createdAt'] ?? ''}';
  UserM get author => UserM(Map<String, dynamic>.from((j['author'] ?? {}) as Map));
  int get likeCount => ((j['likeCount'] ?? 0) as num).toInt();
  int get commentCount => ((j['commentCount'] ?? 0) as num).toInt();
  bool get likedByMe => j['likedByMe'] == true;
  bool get bookmarkedByMe => j['bookmarkedByMe'] == true;
  bool get repostedByMe => j['repostedByMe'] == true;
  bool get savedByMe => j['savedByMe'] == true;
  int get bookmarkCount => ((j['bookmarkCount'] ?? 0) as num).toInt();
  int get repostCount => ((j['repostCount'] ?? 0) as num).toInt();
  int get shareCount => ((j['shareCount'] ?? 0) as num).toInt();
  bool get commentsEnabled => j['commentsEnabled'] != false;
  bool get repostEnabled => j['repostEnabled'] != false;
  bool get pinned => j['pinned'] == true;
  bool get archived => j['archived'] == true;
  String get scheduledAt => '${j['scheduledAt'] ?? ''}';
  List<Map<String, dynamic>> get comments =>
      ((j['comments'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class ReelM {
  ReelM(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id'] ?? ''}';
  String get videoUrl => '${j['videoUrl'] ?? ''}';
  String get caption => '${j['caption'] ?? ''}';
  String get musicTitle => '${j['musicTitle'] ?? ''}';
  String get musicUrl => '${j['musicUrl'] ?? ''}';
  String get title => '${j['title'] ?? ''}';
  int get rotationDegrees => ((j['rotationDegrees'] ?? 0) as num).toInt();
  String get overlayText => '${j['overlayText'] ?? ''}';
  String get overlayEmoji => '${j['overlayEmoji'] ?? ''}';
  String get overlayImageUrl => '${j['overlayImageUrl'] ?? ''}';
  int get views => ((j['views'] ?? 0) as num).toInt();
  int get likeCount => ((j['likeCount'] ?? 0) as num).toInt();
  int get commentCount => ((j['commentCount'] ?? 0) as num).toInt();
  int get shareCount => ((j['shareCount'] ?? 0) as num).toInt();
  int get repostCount => ((j['repostCount'] ?? 0) as num).toInt();
  bool get repostedByMe => j['repostedByMe'] == true;
  bool get savedByMe => j['savedByMe'] == true;
  int get bookmarkCount => ((j['bookmarkCount'] ?? 0) as num).toInt();
  bool get likedByMe => j['likedByMe'] == true;
  bool get commentsEnabled => j['commentsEnabled'] != false;
  bool get repostEnabled => j['repostEnabled'] != false;
  bool get archived => j['archived'] == true;
  String get scheduledAt => '${j['scheduledAt'] ?? ''}';
  List<Map<String,dynamic>> get comments => ((j['comments'] ?? []) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  UserM get author => UserM(Map<String, dynamic>.from((j['author'] ?? {}) as Map));
}

class StoryM {
  StoryM(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id'] ?? ''}';
  String get mediaUrl => '${j['mediaUrl'] ?? ''}';
  String get type => '${j['type'] ?? 'IMAGE'}';
  String get caption => '${j['caption'] ?? ''}';
  int get rotationDegrees => ((j['rotationDegrees'] ?? 0) as num).toInt();
  String get overlayText => '${j['overlayText'] ?? ''}';
  String get overlayEmoji => '${j['overlayEmoji'] ?? ''}';
  String get overlayImageUrl => '${j['overlayImageUrl'] ?? ''}';
  String get musicUrl => '${j['musicUrl'] ?? ''}';
  String get musicTitle => '${j['musicTitle'] ?? ''}';
  String get createdAt => '${j['createdAt'] ?? ''}';
  String get expiresAt => '${j['expiresAt'] ?? ''}';
  String get audienceMode => '${j['audienceMode'] ?? 'EVERYONE'}';
  bool get replyEnabled => j['replyEnabled'] != false;
  bool get archived => j['archived'] == true;
  int get autoHideViews => ((j['autoHideViews'] ?? 0) as num).toInt();
  bool get likedByMe => j['likedByMe'] == true;
  int get reactionCount => ((j['reactionCount'] ?? 0) as num).toInt();
  List<Map<String, dynamic>> get replies => ((j['replies'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  UserM get author => UserM(Map<String, dynamic>.from((j['author'] ?? {}) as Map));
}

class GroupM {
  GroupM(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id'] ?? ''}';
  String get name => '${j['name'] ?? ''}';
  String get description => '${j['description'] ?? ''}';
  String get avatarUrl => '${j['avatarUrl'] ?? ''}';
  String get coverUrl => '${j['coverUrl'] ?? ''}';
  String get privacy => '${j['privacy'] ?? 'PUBLIC'}';
  String get rules => '${j['rules'] ?? ''}';
  int get members => (((j['_count'] ?? {}) as Map)['members'] ?? 0) as int;
  UserM get owner => UserM(Map<String, dynamic>.from((j['owner'] ?? {}) as Map));
}

class LiveM {
  LiveM(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id'] ?? ''}';
  String get title => '${j['title'] ?? ''}';
  String get roomName => '${j['roomName'] ?? ''}';
  int get viewerCount => ((j['viewerCount'] ?? 0) as num).toInt();
  UserM get host => UserM(Map<String, dynamic>.from((j['host'] ?? {}) as Map));
}
