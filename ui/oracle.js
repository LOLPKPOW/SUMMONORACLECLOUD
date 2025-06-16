window.onload = () => {
  const oracleText = document.getElementById("oracle-text");
  const audio = document.getElementById("oracle-voice");
  const sacredPhrase = "invoke oracle clarity";
  const clarityDurationMs = 120 * 1000; // 2 minutes

  function showClarityBanner() {
    let banner = document.getElementById("clarity-banner");
    if (!banner) {
      banner = document.createElement("div");
      banner.id = "clarity-banner";
      banner.style.position = "fixed";
      banner.style.top = "0";
      banner.style.left = "0";
      banner.style.width = "100%";
      banner.style.backgroundColor = "red";
      banner.style.color = "white";
      banner.style.fontSize = "3em";
      banner.style.fontWeight = "bold";
      banner.style.textAlign = "center";
      banner.style.padding = "1rem 0";
      banner.style.zIndex = "9999";
      banner.style.fontFamily = "monospace";
      banner.textContent = "⚠️ CLARITY MODE ENGAGED ⚠️";
      document.body.appendChild(banner);
    }
    banner.style.display = "block";

    // Hide banner after duration
    clearTimeout(window.clarityBannerTimeout);
    window.clarityBannerTimeout = setTimeout(() => {
      banner.style.display = "none";
    }, clarityDurationMs);
  }

  window.askOracle = function () {
    oracleText.innerText = "Speak your question to the Oracle...";

    const recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    recognition.lang = "en-US";
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    recognition.onresult = function (event) {
      const question = event.results[0][0].transcript;
      oracleText.innerText = `"${question}" received... consulting the void.`;

      fetch("/presence", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question }),
      })
        .then((res) => res.json())
        .then((data) => {
          console.log("Audio URL from API:", data.audio_file);
          oracleText.innerText = data.spoken;

          audio.pause();
          audio.src = data.audio_file;
          audio.load();
          audio.oncanplaythrough = () => {
            audio
              .play()
              .catch((err) => {
                console.error("Audio playback failed:", err);
                oracleText.innerText = "The Oracle refuses to speak. Try again.";
              });
          };

          // Show clarity banner if sacred phrase detected
          if (question.toLowerCase().includes(sacredPhrase)) {
            showClarityBanner();
          }
        })
        .catch((err) => {
          console.error("Error during fetch or playback:", err);
          oracleText.innerText = "The Oracle encountered a disturbance.";
        });
    };

    recognition.onerror = function (event) {
      console.error("Speech recognition error:", event.error);
      oracleText.innerText = "The Oracle choked on your words. Try again.";
    };

    recognition.onend = function () {
      console.log("Voice recognition ended");
    };

    recognition.start();
  };
};
