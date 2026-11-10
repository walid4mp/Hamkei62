export const colors = {
  primary: "#5B67F1",
  secondary: "#8B5CF6",
  accent: "#00D4FF",
  bg: "#0D0E15",
  surface: "#141622",
  surface2: "#1C1E2E",
  border: "#262A3E",
  text: "#FFFFFF",
  muted: "#8A90A6",
  danger: "#F43F5E",
  gold: "#F59E0B",
  success: "#22C55E",
};
export const gradients = {
  brand: ["#5B67F1", "#8B5CF6"] as const,
  aurora: ["#8B5CF6", "#00D4FF"] as const,
  sunset: ["#F43F5E", "#F59E0B"] as const,
};
export const radius = { sm: 10, md: 16, lg: 24, xl: 32, full: 999 };
export const spacing = (n: number) => n * 4;
export type Palette = typeof colors;
