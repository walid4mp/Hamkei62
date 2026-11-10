/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./App.tsx", "./src/**/*.{ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        primary: "#5B67F1",
        secondary: "#8B5CF6",
        accent: "#00D4FF",
        night: { 950: "#0D0E15", 900: "#141622", 800: "#1C1E2E", 700: "#262A3E", 600: "#343A52" },
        muted: "#8A90A6",
      },
    },
  },
  plugins: [],
};
