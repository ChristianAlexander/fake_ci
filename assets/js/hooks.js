const TimeAgo = {
  mounted() {
    this.updateTime();
    this.interval = setInterval(() => this.updateTime(), 1000); // Update every second for demo
  },

  updated() {
    this.updateTime();
  },

  destroyed() {
    if (this.interval) {
      clearInterval(this.interval);
    }
  },

  updateTime() {
    const el = this.el;
    const timestamp = el.dataset.timestamp;
    if (timestamp && timestamp !== "null" && timestamp !== "undefined") {
      try {
        const datetime = new Date(timestamp);
        if (!isNaN(datetime.getTime())) {
          const timeAgo = this.calculateTimeAgo(datetime);
          el.textContent = timeAgo;
        }
      } catch (error) {
        console.warn(
          "TimeAgo hook: Invalid timestamp format:",
          timestamp,
          error,
        );
      }
    }
  },

  calculateTimeAgo(datetime) {
    const now = new Date();
    const diffInSeconds = Math.floor((now - datetime) / 1000);

    // Handle future dates
    if (diffInSeconds < 0) {
      return "in the future";
    }

    // Handle "just now" case
    if (diffInSeconds < 5) {
      return "just now";
    }

    // Seconds (up to 59 seconds)
    if (diffInSeconds < 60) {
      return `${diffInSeconds}s ago`;
    }

    // Minutes (up to 59 minutes)
    const diffInMinutes = Math.floor(diffInSeconds / 60);
    if (diffInMinutes < 60) {
      return `${diffInMinutes}m ago`;
    }

    // Everything else is "a while ago"
    return "a while ago";
  },
};

const Hooks = {
  TimeAgo,
};

export default Hooks;
