// ==UserScript==
// @name         Fix YouTube Live Chat 30 sec delay
// @namespace    UserScripts
// @version      3.25
// @description  Fix YouTube Live Chat 30 sec delay
// @author       Mr THP
// @license      MIT
// @icon         https://upload.wikimedia.org/wikipedia/commons/9/98/Microsoft_Edge_logo_%282019%29.svg
// @match        https://www.youtube.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(async () => {
    const getDMPromise = (() => {
        const attrName = `dm-${Date.now()}-${Math.floor(Math.random() * 314159265359 + 314159265359).toString(36)}`;
        let val = 0;
        let _dmPromise = null;

        return async (chatframe) => {
            if (_dmPromise) return _dmPromise;
            _dmPromise = new Promise(resolve => {
                const mo = new MutationObserver(resolve);
                mo.observe(chatframe, { attributes: true });
                chatframe.setAttribute(attrName, ++val);
            }).then(() => {
                _dmPromise = null;
            }).catch(console.warn);
            return _dmPromise;
        };
    })();

    await customElements.whenDefined('ytd-live-chat-frame');
    const chat = document.createElement('ytd-live-chat-frame');
    if (!chat || chat.is !== 'ytd-live-chat-frame') return;

    const cnt = chat.polymerController || chat.inst || chat || 0;
    const cProto = cnt.constructor.prototype || 0;

    if (typeof cProto.urlChanged === 'function' && !cProto.urlChanged66) {
        const originalUrlChanged = cProto.urlChanged;
        let ath = 0;
        cProto.urlChanged = async function () {
            if (ath > 1e9) ath = 9;
            const t = ++ath;
            const chatframe = this.chatframe || (this.$ || 0).chatframe || 0;
            if (chatframe) {
                if (chatframe.contentDocument === null) await Promise.resolve();
                if (t !== ath) return;
                await getDMPromise(chatframe); // next macroTask
                if (t !== ath) return;
            }
            originalUrlChanged.call(this);
        }
    }
})();
