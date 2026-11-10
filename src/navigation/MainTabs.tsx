import React from "react";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { Text, Pressable, View, StyleSheet } from "react-native";
import { colors } from "../theme";
import { useI18n } from "../i18n";
import {
  HomeScreen, ReelsScreen, CreatePostScreen, SearchScreen, ChatsScreen,
  ProfileScreen, SettingsScreen, NotificationsScreen, StoriesScreen,
} from "../screens";

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator<any>();

function ChatsStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="ChatsList" component={ChatsScreen} />
    </Stack.Navigator>
  );
}

function ProfileStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="ProfileMain" component={ProfileScreen} />
      <Stack.Screen name="SettingsFromProfile" component={SettingsScreen} />
    </Stack.Navigator>
  );
}

/* أيقونة SVG-free موحدة: دائرة خلفية + إيموجي، حجم موحد 26 */
function TabIcon({ glyph, focused, badge }: { glyph: string; focused: boolean; badge?: number }) {
  return (
    <View style={styles.iconWrap}>
      <View style={[styles.iconBubble, focused && { backgroundColor: "rgba(91,103,241,0.18)" }]}>
        <Text style={{ fontSize: 22, opacity: focused ? 1 : 0.6 }}>{glyph}</Text>
      </View>
      {!!badge && badge > 0 && (
        <View style={styles.badge}>
          <Text style={styles.badgeText}>{badge > 9 ? "9+" : badge}</Text>
        </View>
      )}
    </View>
  );
}

export function MainTabs() {
  const { t, lang } = useI18n();
  /* تسميات قصيرة لا تُقتطع في أي لغة */
  const labels = {
    home: lang === "ar" ? "الرئيسية" : "Home",
    reels: lang === "ar" ? "ريلز" : "Reels",
    chats: lang === "ar" ? "دردشة" : "Chat",
    profile: lang === "ar" ? "حسابي" : "Me",
  };

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarHideOnKeyboard: true,
        tabBarStyle: {
          position: "absolute",
          backgroundColor: "rgba(13,14,21,0.97)",
          borderTopColor: "rgba(139,92,246,0.18)",
          height: 64,
          paddingTop: 6,
          paddingBottom: 10,
        },
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.muted,
        tabBarLabelStyle: { fontSize: 11, fontWeight: "700" },
        tabBarItemStyle: { paddingVertical: 0, marginHorizontal: 2 },
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{ title: labels.home, tabBarIcon: ({ focused }) => <TabIcon glyph="🏠" focused={focused} /> }}
      />
      <Tab.Screen
        name="Reels"
        component={ReelsScreen}
        options={{ title: labels.reels, tabBarIcon: ({ focused }) => <TabIcon glyph="🎬" focused={focused} /> }}
      />
      <Tab.Screen
        name="Create"
        component={CreatePostScreen}
        options={{
          title: "",
          tabBarIcon: () => (
            <View style={styles.createBtn}>
              <Text style={{ color: "#fff", fontSize: 26, fontWeight: "300", marginTop: -3 }}>＋</Text>
            </View>
          ),
        }}
      />
      <Tab.Screen
        name="Chats"
        component={ChatsStack}
        options={{ title: labels.chats, tabBarIcon: ({ focused }) => <TabIcon glyph="💬" focused={focused} /> }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileStack}
        options={{ title: labels.profile, tabBarIcon: ({ focused }) => <TabIcon glyph="👤" focused={focused} /> }}
      />
      {/* شاشات مخفية من الشريط — تُفتح بالتنقل */}
      <Tab.Screen name="Search" component={SearchScreen} options={{ tabBarButton: () => null }} />
      <Tab.Screen name="Notifications" component={NotificationsScreen} options={{ tabBarButton: () => null }} />
      <Tab.Screen name="Settings" component={SettingsScreen} options={{ tabBarButton: () => null }} />
      <Tab.Screen name="Stories" component={StoriesScreen} options={{ tabBarButton: () => null }} />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  iconWrap: { alignItems: "center", justifyContent: "center" },
  iconBubble: { width: 38, height: 30, borderRadius: 10, alignItems: "center", justifyContent: "center" },
  badge: {
    position: "absolute", top: -3, insetInlineEnd: -6,
    backgroundColor: colors.danger, borderRadius: 8, minWidth: 16, height: 16,
    alignItems: "center", justifyContent: "center", paddingHorizontal: 4,
  },
  badgeText: { color: "#fff", fontSize: 9, fontWeight: "900" },
  createBtn: {
    width: 52, height: 36, borderRadius: 13,
    backgroundColor: colors.primary,
    alignItems: "center", justifyContent: "center",
    shadowColor: colors.primary, shadowOpacity: 0.5, shadowRadius: 10, shadowOffset: { width: 0, height: 4 },
  },
});
