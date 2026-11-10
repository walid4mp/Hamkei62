import { I18nManager } from "react-native";
export type Lang = "ar" | "en";
export function applyRTL(l: Lang) {
  I18nManager.allowRTL(l === "ar");
}
