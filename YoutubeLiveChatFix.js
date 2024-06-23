// ==UserScript==
// @name         Fix YouTube Live Chat delay
// @namespace    UserScripts
// @version      3.25
// @description  Fix YouTube Live Chat delay
// @author       Mr THP
// @license      MIT
// @icon         https://upload.wikimedia.org/wikipedia/commons/9/98/Microsoft_Edge_logo_%282019%29.svg
// @match        https://www.youtube.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==
(async () => {
  const getDMPromise = (() => {
    let val = 0, _dmPromise = null;
    return async (chatframe) => {
      if (_dmPromise) return _dmPromise;
      const attrName = `dm-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      _dmPromise = new Promise(resolve => {
        const mo = new MutationObserver(resolve);
        mo.observe(chatframe, { attributes: true });
        chatframe.setAttribute(attrName, ++val);
      }).finally(() => _dmPromise = null);
      return _dmPromise;
    };
  })();

  await customElements.whenDefined('ytd-live-chat-frame');
  const chat = document.createElement('ytd-live-chat-frame');
  if (!chat || chat.is !== 'ytd-live-chat-frame') return;

  const cProto = (chat.polymerController || chat.inst || chat).constructor.prototype;
  if (typeof cProto.urlChanged === 'function' && !cProto.urlChanged66) {
    const originalUrlChanged = cProto.urlChanged;
    let ath = 0;
    cProto.urlChanged = async function () {
      const t = ++ath;
      const chatframe = this.chatframe || (this.$ || {}).chatframe;
      if (chatframe && chatframe.contentDocument === null) await Promise.resolve();
      if (t === ath) {
        await getDMPromise(chatframe);
        if (t === ath) originalUrlChanged.call(this);
      }
    }
  }
})();
