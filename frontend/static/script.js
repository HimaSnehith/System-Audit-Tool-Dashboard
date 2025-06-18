document.addEventListener("DOMContentLoaded", function () {
    const hostInput = document.getElementById("target-host");
    const runButton = document.getElementById("run-audit");
    const downloadButton = document.getElementById("download-report");
    const outputLog = document.getElementById("output");
    const scriptsListContainer = document.getElementById("scripts-list");
    const themeToggle = document.getElementById("theme-toggle");
    const themeToggleLabel = document.getElementById("theme-toggle-label"); // For accessibility
    const dashboardLinkContainer = document.getElementById('dashboard-link-container'); // New container

    let detectedOS = null;
    let latestReportPath = null;
    let eventSource = null; // Keep a reference to the EventSource

    // --- Theme Toggle Logic (Goated Functionality) ---
    function initializeTheme() {
        const savedTheme = localStorage.getItem('theme');
        if (savedTheme === 'dark') {
            document.documentElement.classList.add('dark-theme');
            themeToggle.checked = true;
            themeToggleLabel.textContent = 'Disable Dark Mode';
        } else {
            document.documentElement.classList.remove('dark-theme');
            themeToggle.checked = false;
            themeToggleLabel.textContent = 'Enable Dark Mode';
        }
    }

    themeToggle.addEventListener("change", () => {
        if (themeToggle.checked) {
            document.documentElement.classList.add("dark-theme");
            localStorage.setItem('theme', 'dark');
            themeToggleLabel.textContent = 'Disable Dark Mode';
        } else {
            document.documentElement.classList.remove("dark-theme");
            localStorage.setItem('theme', 'light');
            themeToggleLabel.textContent = 'Enable Dark Mode';
        }
    });

    // Initialize theme on page load
    initializeTheme();
    // --- End Theme Toggle Logic ---


    // Initial state for buttons
    downloadButton.disabled = true;
    runButton.disabled = true; // Disabled until OS is detected and scripts are loaded

    function appendToLog(message, isError = false) {
        const line = document.createElement('div');
        line.textContent = message;
        if (isError) {
            line.classList.add('log-error'); // Add a class for error styling
            line.textContent = '❌ ' + message;
        }
        outputLog.appendChild(line);
        outputLog.scrollTop = outputLog.scrollHeight; // Auto-scroll
    }

    // Clear log function
    function clearLog() {
        outputLog.innerHTML = "";
    }

    function detectOS() {
        clearLog(); // Clear log on new detection
        appendToLog("Detecting OS...");
        document.getElementById("os-info").textContent = "Detecting operating system..."; // Reset OS info
        runButton.disabled = true; // Disable run during OS detection
        fetch(`/detect_os?host=${hostInput.value}`)
            .then((res) => {
                if (!res.ok) {
                    throw new Error(`Network response was not ok: ${res.statusText}`);
                }
                return res.json();
            })
            .then((data) => {
                if (data.os) {
                    detectedOS = data.os;
                    document.getElementById("os-info").textContent = `Detected OS: ${detectedOS}`;
                    appendToLog(`Detected OS: ${detectedOS}`);
                    fetchScripts(detectedOS);
                } else {
                    appendToLog(`OS Detection Failed: ${data.error || 'Unknown error'}`, true);
                    runButton.disabled = true; // Keep run button disabled if OS detection fails
                }
            })
            .catch((err) => {
                appendToLog(`Error detecting OS: ${err.message}`, true);
                runButton.disabled = true; // Keep run button disabled on error
            });
    }

    function fetchScripts(os) {
        scriptsListContainer.innerHTML = `<div style="color: var(--main-title-color); padding: 15px;">Loading scripts for ${os}...</div>`;
        fetch(`/get_scripts?os=${os}`)
            .then((res) => {
                if (!res.ok) {
                    throw new Error(`Network response was not ok: ${res.statusText}`);
                }
                return res.json();
            })
            .then((data) => {
                scriptsListContainer.innerHTML = ""; // Clear loading message
                if (data.error) {
                    appendToLog(`Error fetching scripts: ${data.error}`, true);
                    runButton.disabled = true;
                    return;
                }
                const scripts = data.scripts;
                if (Object.keys(scripts).length === 0) {
                    scriptsListContainer.innerHTML = `<div style="padding: 15px;">No scripts found for ${os}.</div>`;
                    runButton.disabled = true; // Disable run if no scripts
                    return;
                }

                Object.keys(scripts).forEach((filename) => {
                    const scriptInfo = scripts[filename];
                    const item = document.createElement("div");
                    item.className = "script-item";
                    item.innerHTML = `
                        <input type="checkbox" id="${filename}" name="scripts" value="${filename}">
                        <label for="${filename}"><strong>${scriptInfo.title || filename}</strong><br/><span>${scriptInfo.description || 'No description'}</span></label>
                    `;
                    scriptsListContainer.appendChild(item);
                });
                runButton.disabled = false; // Enable run button after scripts are loaded
            })
            .catch((err) => {
                scriptsListContainer.innerHTML = ""; // Clear loading message
                appendToLog(`Failed to load scripts: ${err.message}`, true);
                runButton.disabled = true; // Keep run button disabled on error
            });
    }

    runButton.addEventListener("click", () => {
        if (eventSource && eventSource.readyState !== EventSource.CLOSED) {
            appendToLog("An audit is already in progress. Please wait.", true);
            return;
        }

        const checkboxes = document.querySelectorAll(
            'input[name="scripts"]:checked'
        );
        if (!checkboxes.length) {
            appendToLog("Please select at least one script.", true);
            return;
        }

        const selectedScripts = Array.from(checkboxes).map((cb) => cb.value);
        clearLog(); // Clear previous log
        appendToLog("Initiating audit...");

        runButton.disabled = true;
        runButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Running Audit...'; // Add spinner and change text
        downloadButton.disabled = true;
        latestReportPath = null;
        dashboardLinkContainer.innerHTML = ''; // Clear existing dashboard link

        // Construct query parameters correctly
        const params = new URLSearchParams();
        params.append('os', detectedOS);
        selectedScripts.forEach(script => params.append('scripts', script));

        eventSource = new EventSource(`/stream_output?${params.toString()}`);

        eventSource.onmessage = function (event) {
            const line = event.data;
            
            if (line.startsWith("REPORT_PATH::")) {
                latestReportPath = line.split("::")[1].trim();
                appendToLog(`Report generated: ${latestReportPath}`);
                downloadButton.disabled = false; // Enable download button
                if (eventSource) {
                    eventSource.close(); // Close the connection as we have the report path
                }
                runButton.disabled = false; // Re-enable run button
                runButton.innerHTML = '<i class="fas fa-play"></i> Run Selected Audit Scripts'; // Reset button text

                // Add dashboard link to its dedicated container
                const dashboardLink = document.createElement("a");
                dashboardLink.href = window.location.origin;
                dashboardLink.textContent = "Open Dashboard in New Tab";
                dashboardLink.target = "_blank";
                dashboardLink.classList.add('btn', 'btn-primary', 'btn-small'); // Add styling classes
                dashboardLinkContainer.appendChild(dashboardLink);

            } else {
                appendToLog(line); // Append normal log lines
            }
        };

        eventSource.onerror = function () {
            appendToLog(
                "Connection to audit stream failed or was interrupted. Please check server logs and try again.", true
            );
            if (eventSource) {
                eventSource.close();
            }
            runButton.disabled = false; // Re-enable run button on error
            runButton.innerHTML = '<i class="fas fa-play"></i> Run Selected Audit Scripts'; // Reset button text
            downloadButton.disabled = true; // Ensure download is disabled
        };
    });

    downloadButton.addEventListener("click", () => {
        if (!latestReportPath) {
            appendToLog("No report available to download.", true);
            return;
        }

        appendToLog("Preparing report for download...");
        const link = document.createElement("a");
        link.href = `/download_report?path=${encodeURIComponent(latestReportPath)}`;
        link.download = latestReportPath.split(/[\\/]/).pop() || "audit_report.pdf"; // Extract filename
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        appendToLog("Download initiated.");
    });

    // Initial OS detection on page load
    detectOS();

    // Re-detect OS if host input changes (debounce for better UX)
    let detectOSTimer;
    hostInput.addEventListener('input', () => {
        clearTimeout(detectOSTimer);
        detectOSTimer = setTimeout(() => {
            detectOS();
        }, 500); // 500ms debounce
    });
});