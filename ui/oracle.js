window.onload = () => {
  const oracleText = document.getElementById("oracle-text");
  const audio = document.getElementById("oracle-voice");

  window.askOracle = function () {
    oracleText.innerText = "Speak your question to the Oracle...";

    const recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    recognition.lang = 'en-US';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    recognition.onresult = function (event) {
      const question = event.results[0][0].transcript;
      oracleText.innerText = `"${question}" received... consulting the void.`;

      fetch('/presence', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question })
      })
        .then(res => res.json())
        .then(data => {
          console.log("Audio URL from API:", data.audio_file);
          oracleText.innerText = data.spoken;

          audio.pause();
          audio.src = data.audio_file;
          audio.load();
          audio.oncanplaythrough = () => {
            audio.play().catch(err => {
              console.error("Audio playback failed:", err);
              oracleText.innerText = "The Oracle refuses to speak. Try again.";
            });
          };
        })
        .catch(err => {
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
