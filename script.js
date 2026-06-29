// Configuration
const CONFIG = {
    codeLength: 4,
    maxAttempts: 10,
    fakeSuccessThreshold: 7, // Après 7 tentatives, commencer à donner de faux espoirs
    messages: {
        initial: "Entrez un code à 4 chiffres",
        success: [
            "Presque...!",
            "C'est presque ça...",
            "Vous y êtes presque...",
            "Encore un effort...",
            "Le coffre frémit...",
            "La serrure bouge...",
            "C'est pour bientôt...",
            "Presque ouvert..."
        ],
        error: [
            "Code incorrect",
            "Essayez encore",
            "Mauvais code",
            "Accès refusé",
            "Ce n'est pas le bon",
            "Réessayez",
            "Non, ce n'est pas ça"
        ],
        warning: [
            "Attention, dernière chance...",
            "Le système se verrouille...",
            "Trop de tentatives...",
            "Dernier essai autorisé"
        ]
    },
    // Codes qui semblent proches mais ne fonctionnent jamais
    fakeCloseCodes: [
        "1234", "4321", "1111", "2222", "3333", "4444",
        "1212", "1313", "2121", "2323", "3131", "3232",
        "0000", "9999", "1122", "2211", "1235", "5432",
        "2468", "8642", "1357", "7531", "2580", "0852"
    ]
};

// État de l'application
let state = {
    currentCode: '',
    attempts: [],
    attemptCount: 0,
    isLocked: false,
    lockoutTime: 0,
    lastAttemptTime: 0
};

// Éléments DOM
const elements = {
    datetime: document.getElementById('datetime'),
    codeDisplay: document.getElementById('code-display'),
    keypad: document.getElementById('keypad'),
    message: document.getElementById('message'),
    messageContainer: document.getElementById('message-container'),
    attemptsList: document.getElementById('attempts-list'),
    safeDoor: document.getElementById('safe-door'),
    lock: document.getElementById('lock'),
    safe: document.getElementById('safe'),
    clickSound: document.getElementById('click-sound'),
    errorSound: document.getElementById('error-sound'),
    successSound: document.getElementById('success-sound'),
    lockSound: document.getElementById('lock-sound')
};

// Initialisation
function init() {
    updateDateTime();
    setInterval(updateDateTime, 1000);
    
    // Ajouter les écouteurs d'événements
    elements.keypad.addEventListener('click', handleKeyPress);
    
    // Écouteur pour le clavier physique
    document.addEventListener('keydown', handleKeyboardInput);
    
    // Initialiser l'affichage
    updateDisplay();
    
    // Message initial
    showMessage('initial');
    
    // Charger l'historique si disponible
    loadAttempts();
    
    // Animation initiale du coffre
    setTimeout(() => {
        elements.safe.style.transform = 'translateY(0)';
        elements.safe.style.opacity = '1';
    }, 100);
}

// Mettre à jour la date et l'heure
function updateDateTime() {
    const now = new Date();
    const options = {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false
    };
    elements.datetime.textContent = now.toLocaleDateString('fr-FR', options);
}

// Gérer la pression sur les touches
function handleKeyPress(e) {
    const key = e.target.closest('.key');
    if (!key) return;
    
    const value = key.dataset.value;
    
    // Jouer le son de clic
    playSound(elements.clickSound);
    
    // Animation du bouton
    key.classList.add('active');
    setTimeout(() => key.classList.remove('active'), 100);
    
    if (value === 'C') {
        clearCode();
    } else if (value === '✓') {
        submitCode();
    } else {
        addDigit(value);
    }
}

// Gérer l'entrée clavier
function handleKeyboardInput(e) {
    if (state.isLocked) return;
    
    const key = e.key;
    
    if (/\d/.test(key)) {
        addDigit(key);
        playSound(elements.clickSound);
    } else if (key === 'Enter' || key === '=') {
        submitCode();
        playSound(elements.clickSound);
    } else if (key === 'Backspace' || key === 'Delete' || key === 'Escape') {
        clearCode();
        playSound(elements.clickSound);
    }
}

// Ajouter un chiffre au code
function addDigit(digit) {
    if (state.isLocked) return;
    if (state.currentCode.length >= CONFIG.codeLength) return;
    
    state.currentCode += digit;
    updateDisplay();
    
    // Animation de feedback
    elements.lock.classList.add('unlock-attempt');
    setTimeout(() => {
        elements.lock.classList.remove('unlock-attempt');
    }, 300);
}

// Effacer le code
function clearCode() {
    state.currentCode = '';
    updateDisplay();
}

// Mettre à jour l'affichage du code
function updateDisplay() {
    let displayText = '';
    for (let i = 0; i < CONFIG.codeLength; i++) {
        if (i < state.currentCode.length) {
            displayText += state.currentCode[i];
        } else {
            displayText += '_';
        }
    }
    elements.codeDisplay.textContent = displayText;
}

// Soumettre le code
function submitCode() {
    if (state.isLocked) {
        const remainingTime = Math.max(0, Math.ceil((state.lockoutTime - Date.now()) / 1000));
        showMessage(`warning`, `Verrouillé pour ${remainingTime} secondes`);
        playSound(elements.errorSound);
        return;
    }
    
    if (state.currentCode.length < CONFIG.codeLength) {
        showMessage('error', "Code incomplet");
        playSound(elements.errorSound);
        return;
    }
    
    state.attemptCount++;
    const attempt = {
        code: state.currentCode,
        timestamp: new Date().toLocaleTimeString('fr-FR'),
        success: false
    };
    
    state.attempts.unshift(attempt);
    if (state.attempts.length > 10) {
        state.attempts.pop();
    }
    
    updateAttemptsList();
    saveAttempts();
    
    // Vérifier si c'est un code qui semble proche
    const isFakeClose = CONFIG.fakeCloseCodes.includes(state.currentCode);
    
    // Après un certain nombre de tentatives, donner de faux espoirs
    const shouldFakeSuccess = state.attemptCount >= CONFIG.fakeSuccessThreshold || isFakeClose;
    
    if (shouldFakeSuccess) {
        // Animation de faux succès
        fakeSuccessAnimation();
        
        // Message de faux espoir
        const successMessages = CONFIG.messages.success;
        const randomMessage = successMessages[Math.floor(Math.random() * successMessages.length)];
        showMessage('success', randomMessage);
        playSound(elements.successSound);
    } else {
        // Animation d'échec
        fakeErrorAnimation();
        
        // Message d'erreur
        const errorMessages = CONFIG.messages.error;
        const randomMessage = errorMessages[Math.floor(Math.random() * errorMessages.length)];
        showMessage('error', randomMessage);
        playSound(elements.errorSound);
    }
    
    // Réinitialiser le code
    clearCode();
    
    // Vérifier si on doit verrouiller
    if (state.attemptCount >= CONFIG.maxAttempts) {
        lockSystem();
    } else if (state.attemptCount >= CONFIG.maxAttempts - 2) {
        const warningMessages = CONFIG.messages.warning;
        const randomMessage = warningMessages[Math.floor(Math.random() * warningMessages.length)];
        showMessage('warning', randomMessage);
    }
}

// Animation de faux succès
function fakeSuccessAnimation() {
    // Animation de la porte
    elements.safeDoor.classList.add('fake-open');
    elements.lock.classList.add('fake-unlock');
    
    // Effet de lumière
    elements.safe.style.boxShadow = '0 0 50px rgba(72, 219, 251, 0.5)';
    
    // Son de serrure
    setTimeout(() => {
        playSound(elements.lockSound);
    }, 500);
    
    // Réinitialiser les animations
    setTimeout(() => {
        elements.safeDoor.classList.remove('fake-open');
        elements.lock.classList.remove('fake-unlock');
        elements.safe.style.boxShadow = '';
    }, 1500);
}

// Animation de faux échec
function fakeErrorAnimation() {
    // Animation de secousse
    elements.safeDoor.classList.add('open-attempt');
    elements.lock.classList.add('unlock-attempt');
    
    // Effet de lumière rouge
    elements.safe.style.boxShadow = '0 0 50px rgba(255, 107, 107, 0.5)';
    
    // Réinitialiser les animations
    setTimeout(() => {
        elements.safeDoor.classList.remove('open-attempt');
        elements.lock.classList.remove('unlock-attempt');
        elements.safe.style.boxShadow = '';
    }, 500);
}

// Verrouiller le système
function lockSystem() {
    state.isLocked = true;
    state.lockoutTime = Date.now() + 30000; // 30 secondes
    state.lastAttemptTime = Date.now();
    
    showMessage('warning', "Système verrouillé pour 30 secondes");
    playSound(elements.errorSound);
    
    // Animation de verrouillage
    elements.lock.style.transform = 'translate(-50%, -50%) rotate(-90deg)';
    elements.safeDoor.style.background = 'linear-gradient(145deg, #8b0000, #6b0000)';
    
    // Réinitialiser après le temps de verrouillage
    setTimeout(() => {
        state.isLocked = false;
        elements.lock.style.transform = 'translate(-50%, -50%) rotate(0)';
        elements.safeDoor.style.background = 'linear-gradient(145deg, #5a5a5a, #3a3a3a)';
        showMessage('initial', "Vous pouvez réessayer");
    }, 30000);
}

// Afficher un message
function showMessage(type, text) {
    elements.message.textContent = text;
    elements.message.className = 'message ' + type;
    
    // Animation
    elements.messageContainer.style.transform = 'translateY(0)';
    setTimeout(() => {
        elements.messageContainer.style.transform = 'translateY(0)';
    }, 10);
}

// Mettre à jour la liste des tentatives
function updateAttemptsList() {
    elements.attemptsList.innerHTML = '';
    
    state.attempts.forEach(attempt => {
        const li = document.createElement('li');
        li.textContent = `${attempt.code} - ${attempt.timestamp}`;
        
        if (attempt.success) {
            li.style.color = '#48dbfb';
        } else {
            li.style.color = '#ff6b6b';
        }
        
        elements.attemptsList.appendChild(li);
    });
}

// Sauvegarder les tentatives dans localStorage
function saveAttempts() {
    try {
        localStorage.setItem('safeAttempts', JSON.stringify(state.attempts));
    } catch (e) {
        console.log('Impossible de sauvegarder les tentatives');
    }
}

// Charger les tentatives depuis localStorage
function loadAttempts() {
    try {
        const saved = localStorage.getItem('safeAttempts');
        if (saved) {
            state.attempts = JSON.parse(saved);
            state.attemptCount = state.attempts.length;
            updateAttemptsList();
        }
    } catch (e) {
        console.log('Impossible de charger les tentatives');
    }
}

// Jouer un son
function playSound(audioElement) {
    try {
        audioElement.currentTime = 0;
        audioElement.play().catch(e => {
            console.log('Erreur de lecture audio:', e);
        });
    } catch (e) {
        console.log('Erreur audio:', e);
    }
}

// Démarrer l'application
window.addEventListener('DOMContentLoaded', init);

// Animation initiale au chargement
document.addEventListener('DOMContentLoaded', () => {
    elements.safe.style.transform = 'translateY(20px)';
    elements.safe.style.opacity = '0';
    elements.safe.style.transition = 'all 0.5s ease';
});

// Effet de fond animé
function createParticle() {
    const particle = document.createElement('div');
    particle.className = 'particle';
    particle.style.cssText = `
        position: fixed;
        width: ${Math.random() * 5 + 2}px;
        height: ${Math.random() * 5 + 2}px;
        background: rgba(255, 255, 255, ${Math.random() * 0.5 + 0.1});
        border-radius: 50%;
        left: ${Math.random() * 100}%;
        top: ${Math.random() * 100}%;
        pointer-events: none;
        z-index: 0;
        animation: float ${Math.random() * 10 + 10}s linear infinite;
    `;
    
    document.body.appendChild(particle);
    
    setTimeout(() => {
        particle.remove();
    }, 20000);
}

// Ajouter des particules en arrière-plan
setInterval(createParticle, 3000);

// Animation CSS pour les particules
const style = document.createElement('style');
style.textContent = `
    @keyframes float {
        0% {
            transform: translateY(100vh) rotate(0deg);
            opacity: 0;
        }
        10% {
            opacity: 1;
        }
        90% {
            opacity: 1;
        }
        100% {
            transform: translateY(-100vh) rotate(720deg);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
