const quoteSets = {
  quiet: [
    {
      text: "選ばなかった道にも、<br>たぶん工事中はある。",
      reflection: "選ばなかったものを、美化していないだろうか。",
      theme: "# 選択について",
      aside: "たぶんね。",
    },
    {
      text: "立ち止まると、<br>景色のほうが動き出す。",
      reflection: "進んでいない時間にも、何かは変わっているだろうか。",
      theme: "# 休息について",
      aside: "急がなくても。",
    },
  ],
  foggy: [
    {
      text: "自分探しの旅に出た。<br>留守だった。",
      reflection: "探している自分は、見つかる側の準備ができているだろうか。",
      theme: "# 自分について",
      aside: "また来ます。",
    },
    {
      text: "霧の中にも道はある。<br>見えないけれど。",
      reflection: "見えないことと、ないことを混同していないだろうか。",
      theme: "# 不確かさについて",
      aside: "足元から。",
    },
  ],
  thinking: [
    {
      text: "深く考えるほど、<br>浅い眠りになる。",
      reflection: "その問いは、今夜まで起きている必要があるだろうか。",
      theme: "# 思考について",
      aside: "寝ようか。",
    },
    {
      text: "答えが出ないのは、問いが<br>まだ帰りたくないからだ。",
      reflection: "今日は、問いを泊めておくだけでもよいだろうか。",
      theme: "# 答えについて",
      aside: "布団は一つ。",
    },
  ],
};

const monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
const weekdayNames = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];

const state = {
  mood: "quiet",
  index: 0,
};

const quoteCard = document.querySelector("#quoteCard");
const quoteText = document.querySelector("#quoteText");
const reflectionText = document.querySelector("#reflectionText");
const quoteTheme = document.querySelector("#quoteTheme");
const thoughtBubble = document.querySelector("#thoughtBubble");
const mascotButton = document.querySelector("#mascotButton");
const favoriteButton = document.querySelector("#favoriteButton");
const soundButton = document.querySelector("#soundButton");

function setDate() {
  const today = new Date();
  document.querySelector("#dateNumber").textContent = String(today.getDate()).padStart(2, "0");
  document.querySelector("#monthName").textContent = monthNames[today.getMonth()];
  document.querySelector("#weekdayName").textContent = weekdayNames[today.getDay()];
}

function currentQuote() {
  return quoteSets[state.mood][state.index % quoteSets[state.mood].length];
}

function renderQuote({ animate = true } = {}) {
  const update = () => {
    const quote = currentQuote();
    quoteText.innerHTML = quote.text;
    reflectionText.textContent = quote.reflection;
    quoteTheme.textContent = quote.theme;
    thoughtBubble.textContent = quote.aside;
    favoriteButton.setAttribute("aria-pressed", "false");
    favoriteButton.setAttribute("aria-label", "お気に入りに追加");
  };

  if (!animate) {
    update();
    return;
  }

  quoteCard.classList.remove("is-flipping");
  void quoteCard.offsetWidth;
  quoteCard.classList.add("is-flipping");
  window.setTimeout(update, 290);
}

function pokeIsh() {
  mascotButton.classList.remove("is-poked");
  void mascotButton.offsetWidth;
  mascotButton.classList.add("is-poked");
  window.setTimeout(() => mascotButton.classList.remove("is-poked"), 1800);
}

document.querySelectorAll("[data-mood]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-mood]").forEach((item) => item.setAttribute("aria-pressed", "false"));
    button.setAttribute("aria-pressed", "true");
    state.mood = button.dataset.mood;
    state.index = 0;
    renderQuote();
    window.setTimeout(pokeIsh, 360);
  });
});

document.querySelector("#nextButton").addEventListener("click", () => {
  state.index += 1;
  renderQuote();
});

favoriteButton.addEventListener("click", () => {
  const selected = favoriteButton.getAttribute("aria-pressed") === "true";
  favoriteButton.setAttribute("aria-pressed", String(!selected));
  favoriteButton.setAttribute("aria-label", selected ? "お気に入りに追加" : "お気に入りから削除");
  if (!selected) pokeIsh();
});

soundButton.addEventListener("click", () => {
  const enabled = soundButton.getAttribute("aria-pressed") === "true";
  soundButton.setAttribute("aria-pressed", String(!enabled));
});

mascotButton.addEventListener("click", pokeIsh);
mascotButton.addEventListener("keydown", (event) => {
  if (event.key === "Enter" || event.key === " ") {
    event.preventDefault();
    pokeIsh();
  }
});

quoteCard.addEventListener("animationend", () => quoteCard.classList.remove("is-flipping"));

setDate();
renderQuote({ animate: false });
