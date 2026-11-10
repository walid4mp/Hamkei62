export type Json = Record<string, unknown> | Json[] | string | number | boolean | null;

export interface Profile {
  id: string;
  username: string;
  full_name: string | null;
  avatar_url: string | null;
  cover_url: string | null;
  bio: string | null;
  phone: string | null;
  website: string | null;
  is_verified: boolean;
  is_admin: boolean;
  is_banned: boolean;
  coins: number;
  is_private: boolean;
  allow_messages: "everyone" | "following" | "nobody";
  show_online: boolean;
  show_last_seen: boolean;
  created_at: string;
}

export interface Post {
  id: string;
  user_id: string;
  content: string;
  media_urls: string[];
  media_type: "text" | "image" | "video";
  location: string | null;
  like_count: number;
  comment_count: number;
  created_at: string;
  profiles?: Profile;
}

export interface Story {
  id: string;
  user_id: string;
  media_url: string | null;
  caption: string | null;
  music: string | null;
  expires_at: string;
  created_at: string;
  profiles?: Profile;
}

export interface Reel {
  id: string;
  user_id: string;
  video_url: string;
  caption: string | null;
  like_count: number;
  comment_count: number;
  share_count: number;
  created_at: string;
  profiles?: Profile;
}

export interface Conversation {
  id: string;
  is_group: boolean;
  title: string | null;
  last_message: string | null;
  updated_at: string;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  kind: "text" | "image" | "video" | "file" | "voice" | "gift";
  media_url: string | null;
  reply_to: string | null;
  edited: boolean;
  deleted: boolean;
  created_at: string;
  profiles?: Profile;
}

export interface NotificationRow {
  id: string;
  user_id: string;
  actor_id: string;
  kind: "like" | "comment" | "follow" | "message" | "live" | "system";
  entity_id: string | null;
  read: boolean;
  created_at: string;
  profiles?: Profile;
}

export interface Gift {
  id: string;
  name: string;
  icon: string;
  price: number;
}

export interface GiftSent {
  id: string;
  gift_id: string;
  sender_id: string;
  receiver_id: string;
  stream_id: string | null;
  quantity: number;
  created_at: string;
}

export interface Stream {
  id: string;
  host_id: string;
  title: string;
  viewer_count: number;
  coin_count: number;
  status: "live" | "ended";
  created_at: string;
  profiles?: Profile;
}

export interface Follow {
  follower_id: string;
  following_id: string;
  status: "accepted" | "pending";
  created_at: string;
}

export interface LiveMessage {
  id: string;
  stream_id: string;
  user_id: string;
  content: string;
  created_at: string;
  profiles?: Profile;
}

export interface StreamExtended extends Stream {
  ended_at: string | null;
  peak_viewers: number;
}

export interface Report {
  id: string;
  reporter_id: string;
  entity_type: "post" | "user" | "comment" | "message";
  entity_id: string;
  reason: string;
  status: "open" | "resolved" | "rejected";
  created_at: string;
}
