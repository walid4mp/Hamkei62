import React from "react";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import { AuthStack } from "./AuthStack";
import { MainTabs } from "./MainTabs";
import {
  SplashScreen, OnboardingScreen, OtpScreen, OutroScreen,
  StoryViewerScreen, ChatRoomScreen, AudioCallScreen, VideoCallScreen,
  LiveStreamScreen, EditProfileScreen, WalletScreen, AdminScreen, CommentsScreen,
} from "../screens";

export type RootParams = {
  Splash: undefined; Onboarding: undefined; Auth: undefined; Main: undefined;
  Otp: { email: string } | undefined; Outro: undefined;
  StoryViewer: { userId?: string } | undefined;
  ChatRoom: { conversationId: string; title: string };
  AudioCall: { name: string } | undefined;
  VideoCall: { name: string } | undefined;
  LiveStream: { streamId?: string } | undefined;
  EditProfile: undefined; Wallet: undefined; Admin: undefined; Comments: { postId: string };
};

const Stack = createNativeStackNavigator<RootParams>();

const navTheme = {
  ...DarkTheme,
  colors: { ...DarkTheme.colors, background: colors.bg, primary: colors.primary, card: colors.surface },
};

export function RootNavigator() {
  const session = useAppStore((s) => s.session);
  const profile = useAppStore((s) => s.profile);
  const { lang } = useI18n();

  const initialOnboarding = !session; // أول تشغيل → Splash ثم Onboarding

  return (
    <NavigationContainer key={lang} theme={navTheme}>
      <Stack.Navigator
        screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg }, animation: "slide_from_right" }}
      >
        {initialOnboarding ? (
          <>
            <Stack.Screen name="Splash" component={SplashScreen} />
            <Stack.Screen name="Onboarding" component={OnboardingScreen} />
            <Stack.Screen name="Auth" component={AuthStack} />
          </>
        ) : (
          <Stack.Screen name="Main" component={MainTabs} />
        )}
        <Stack.Screen name="Otp" component={OtpScreen} />
        <Stack.Screen name="Outro" component={OutroScreen} />
        <Stack.Screen name="StoryViewer" component={StoryViewerScreen} />
        <Stack.Screen name="ChatRoom" component={ChatRoomScreen} />
        <Stack.Screen name="AudioCall" component={AudioCallScreen} />
        <Stack.Screen name="VideoCall" component={VideoCallScreen} />
        <Stack.Screen name="LiveStream" component={LiveStreamScreen} />
        <Stack.Screen name="EditProfile" component={EditProfileScreen} />
        <Stack.Screen name="Wallet" component={WalletScreen} />
        <Stack.Screen name="Admin" component={AdminScreen} />
        <Stack.Screen name="Comments" component={CommentsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
