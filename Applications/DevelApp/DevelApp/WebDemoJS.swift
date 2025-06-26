//
//  WebDemoJS.swift
//  DevelApp
//


public struct WebDemoJS {

    // Currently not used in the demo pending better infrastructure for handling tokens vis-a-vis git commits.
    public static func brumScript() -> String {
        return """
        <script src="https://cdn.signalfx.com/o11y-gdi-rum/latest/splunk-otel-web.js" crossorigin="anonymous">
        </script>
        <script>
            SplunkRum.init(
            {
                realm: '<realm>',
                rumAccessToken: '<token>',
                applicationName: 'com.splunk.rum.DevelApp',
                version: '1.0'
            });
        </script>
        <script type="module">
            import { trace } from 'https://cdn.jsdelivr.net/npm/@opentelemetry/api@1.5.0/build/esm/index.js';
            async function reportPeriodically() {
                const tracer = trace.getTracer('testingDevelApp');
                const span = tracer.startSpan('report');
                span.setAttribute('testNativeSessionId', window.SplunkRumNative.getNativeSessionId());
                span.end();
            }
            setInterval(reportPeriodically, 10000);
        </script>
        """
    }

    // This provides an optional async version of the call, `getNativeSessionIdAsync()`, for BRUM when BRUM is ready to use that.
    public static func modernScriptExample() -> String {
        return """
        async function updateSessionId() {
            try {
                const response = await window.SplunkRumNative.getNativeSessionIdAsync();
                document.getElementById('sessionId').innerText = response;
            } catch (error) {
                document.getElementById('sessionId').innerText = "unknown";
                console.log(`Error getting native Session ID: ${error.message}`);
            }
        }
        setInterval(updateSessionId, 1000);
        """
    }

    // This is the default case today. Here "legacy" (not to be confused with "legacy call" which is about how the integration is done in the iOS code) refers to the BRUM agent using `getNativeSessionId()`, a sync function, as it currently does. Non-legacy would be a different hypothetical future rev of the BRUM agent that wants an async call; they would call `await getNativeSessionAsync()` as seen elsewhere in the "modern" examples.
    public static func legacyScriptExample() -> String {
        return """
        function updateSessionId() {
            try {
                const sessionId = window.SplunkRumNative.getNativeSessionId();
                document.getElementById('sessionId').innerText = sessionId;
            } catch (error) {
                document.getElementById('sessionId').innerText = "unknown";
                console.log(`Error getting native Session ID: ${error.message}`);
            }
        }
        setInterval(updateSessionId, 1000);
        """
    }

    // This script's only purpose is to set the callback.
    // It will be injected alongside the existing polling script.
    public static func callbackSetupScript() -> String {
        return """
        function handleSessionIdChange(change) {
            const statusElement = document.getElementById('callbackStatus');
            const timestamp = new Date(change.timestamp).toLocaleTimeString();
            statusElement.innerHTML = `
                Callback fired at ${timestamp}:<br>
                <span style="font-size: 36px; word-break: break-all;">
                    Previous: ${change.previousId}<br>
                    Current: ${change.currentId}
                </span>
            `;
            statusElement.style.backgroundColor = '#d4edda'; // Light green
            statusElement.style.border = '1px solid #c3e6cb';
            statusElement.style.padding = '10px';
            statusElement.style.borderRadius = '5px';
        }

        // Wait for the injected SplunkRumNative object to become available, then set the callback.
        function initializeCallback() {
            if (window.SplunkRumNative && window.SplunkRumNative._isInitialized) {
                console.log("[CallbackTest] SplunkRumNative found. Setting onNativeSessionIdChanged callback.");
                window.SplunkRumNative.onNativeSessionIdChanged = handleSessionIdChange;
            } else {
                console.log("[CallbackTest] SplunkRumNative not ready, retrying in 100ms.");
                setTimeout(initializeCallback, 100);
            }
        }
        
        // Start the process once the document is loaded.
        document.addEventListener('DOMContentLoaded', initializeCallback);
        """
    }
}

