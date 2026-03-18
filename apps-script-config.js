// Apps Script configuration for Portal do Ensino
// This configuration is loaded by index.html and used by script.js

// Apps Script URL configuration - Used for ALL data loading
// This URL serves the JSON data directly from Google Sheets
//
// ⚠️ SECURITY WARNING: With authentication removed, this URL is publicly accessible
// and anyone with access to this page can view all data. Consider:
// 1. Implementing access controls at the Apps Script deployment level
// 2. Adding rate limiting to prevent abuse
// 3. Restricting deployment access to specific domains if possible
// 4. Monitoring access logs for suspicious activity
//
// NOTE: turmaURLs and turmasList are populated dynamically from turmas-config.json
//       at startup. To add a new turma year, edit turmas-config.json only.
//       The active dataURL is overridden at runtime based on turma selection.
const appsScriptConfig = {
  dataURL: "https://script.google.com/macros/s/AKfycbx6x-I0PCc1Ym8vx7VYyXmwvx3mY-9i3P16z6-5sJB2v728SlzENKnwy-4uAIHIiDLxGg/exec",
  // turmaURLs and turmasList are populated at runtime from turmas-config.json.
  // The values below are fallbacks used only if turmas-config.json cannot be loaded.
  turmaURLs: {
    "2025": "https://script.google.com/macros/s/AKfycbx6x-I0PCc1Ym8vx7VYyXmwvx3mY-9i3P16z6-5sJB2v728SlzENKnwy-4uAIHIiDLxGg/exec",
    "2026": "https://script.google.com/macros/s/AKfycbxF39enADoiGglxeCOzQbjlrc8CWoWn7eHP2OzyuNiqaD4wiAhnkE57NEGhnl81tC3h/exec"
  },
  turmasList: []
};

// Export configuration for ES6 module import
export default appsScriptConfig;
export { appsScriptConfig };
