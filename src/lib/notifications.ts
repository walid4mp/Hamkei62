import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { supabase } from "./supabase";

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function registerPush(userId: string) {
  try {
    const settings = await Notifications.getPermissionsAsync();
    let granted = settings.granted;
    if (!granted) {
      const req = await Notifications.requestPermissionsAsync();
      granted = req.granted;
    }
    if (!granted) return;
    const token = await Notifications.getExpoPushTokenAsync();
    if (token?.data) {
      await supabase.from("profiles").update({ push_token: token.data }).eq("id", userId);
    }
  } catch {
    // Push يتطلب EAS build مع مفاتيح FCM — نتجاهل بهدوء في Expo Go
  }
}
