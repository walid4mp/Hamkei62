import React, { useEffect, Component } from "react";
import { View, Text } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import * as SplashScreen from "expo-splash-screen";
import "./global.css";
import { I18nProvider } from "./src/i18n";
import { RootNavigator } from "./src/navigation/RootNavigator";
import { useAppStore } from "./src/store/useAppStore";
import { supabase } from "./src/lib/supabase";
import { registerPush } from "./src/lib/notifications";

SplashScreen.preventAutoHideAsync().catch(() => {});

class ErrorBoundary extends Component<{ children: React.ReactNode }, { err?: Error }> {
  state = { err: undefined as Error | undefined };
  static getDerivedStateFromError(err: Error) {
    return { err };
  }
  render() {
    if (this.state.err) {
      return (
        <View style={{ flex: 1, backgroundColor: "#0D0E15", alignItems: "center", justifyContent: "center", padding: 24 }}>
          <Text style={{ color: "#fff", fontSize: 18, fontWeight: "800", marginBottom: 8 }}>تعذّر تحميل الشاشة</Text>
          <Text style={{ color: "#8A90A6", textAlign: "center" }}>
            {String(this.state.err?.message ?? this.state.err)}
          </Text>
        </View>
      );
    }
    return this.props.children;
  }
}

function AuthBridge() {
  const setSession = useAppStore((s) => s.setSession);
  const refreshProfile = useAppStore((s) => s.refreshProfile);
  const hydrated = useAppStore((s) => s.hydrated);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (data.session) refreshProfile();
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setSession(session);
      if (session) refreshProfile();
    });
    return sub.subscription.unsubscribe;
  }, [setSession, refreshProfile]);

  useEffect(() => {
    if (hydrated) SplashScreen.hideAsync().catch(() => {});
  }, [hydrated]);

  const session = useAppStore((s) => s.session);
  useEffect(() => {
    if (session?.user?.id) registerPush(session.user.id);
  }, [session?.user?.id]);

  if (!hydrated) return null;
  return <RootNavigator />;
}

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: "#0D0E15" }}>
      <SafeAreaProvider>
        <I18nProvider>
          <ErrorBoundary>
            <StatusBar style="light" />
            <AuthBridge />
          </ErrorBoundary>
        </I18nProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
