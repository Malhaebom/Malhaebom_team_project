// src/components/ErrorBoundary.jsx
import React from "react";

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { err: null };
  }
  static getDerivedStateFromError(error) {
    return { err: error };
  }
  componentDidCatch(error, info) {
    console.error(`[ErrorBoundary:${this.props.name}]`, error, info);
  }
  render() {
    if (this.state.err) {
      return (
        <div style={{ padding: 16, background: "#ffecec", border: "1px solid #f00" }}>
          <strong>컴포넌트 오류</strong> — {this.props.name}
          <pre style={{ whiteSpace: "pre-wrap" }}>{String(this.state.err)}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}
