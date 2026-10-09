import { ImageResponse } from "next/og";
export const alt =
  "The Last Monsoon — a historical action-adventure set in 1850s India";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export default function Image() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        background: "linear-gradient(140deg,#0c211e,#3f5950)",
        color: "#eae4d1",
        border: "20px solid #172e27",
      }}
    >
      <div style={{ fontSize: 20, letterSpacing: 8, color: "#c0ab76" }}>
        INDIA / 1850s
      </div>
      <div style={{ fontSize: 38, letterSpacing: 18, marginTop: 50 }}>
        THE LAST
      </div>
      <div style={{ fontSize: 112, letterSpacing: 14, marginTop: 10 }}>
        MONSOON
      </div>
      <div style={{ fontSize: 24, marginTop: 45, color: "#c0c6b9" }}>
        A historical action-adventure · In development
      </div>
    </div>,
    size,
  );
}
