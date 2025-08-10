document.addEventListener('DOMContentLoaded', () => {
    // --- DOM Element Selection ---
    const authForm = document.getElementById('auth-form');
    const registerForm = document.getElementById('register-form');
    const calcSection = document.getElementById('calc-section');

    const loginUsernameInput = document.getElementById('login-username');
    const loginPasswordInput = document.getElementById('login-password');
    const registerUsernameInput = document.getElementById('register-username');
    const registerPasswordInput = document.getElementById('register-password');

    const loginButton = document.getElementById('login-button');
    const registerButton = document.getElementById('register-button');
    const showRegisterButton = document.getElementById('show-register-button');
    const showLoginButton = document.getElementById('show-login-button');
    const logoutButton = document.getElementById('logout-button');

    const display = document.getElementById('display');
    const calculatorButtons = document.querySelectorAll('#calculator .calc-button'); // Select all calc buttons

    const loginErrorDiv = document.getElementById('login-error');
    const registerErrorDiv = document.getElementById('register-error');

    const API_BASE_URL = 'http://localhost'; // Frontend sends requests to this base URL

    // --- View Switching Functions ---
    function showLoginView() {
        authForm.classList.add('active');
        registerForm.classList.remove('active');
        calcSection.classList.remove('active'); // Ensure calc is hidden
        clearErrorMessages();
    }

    function showRegisterView() {
        authForm.classList.remove('active');
        registerForm.classList.add('active');
        calcSection.classList.remove('active'); // Ensure calc is hidden
        clearErrorMessages();
    }

    function showCalculatorView() {
        authForm.classList.remove('active');
        registerForm.classList.remove('active');
        calcSection.classList.add('active');
        clearErrorMessages();
        clearDisplay(); // Clear display when showing calculator
    }

    function clearErrorMessages() {
        loginErrorDiv.textContent = '';
        registerErrorDiv.textContent = '';
    }

    function displayError(type, message) {
        if (type === 'login') {
            loginErrorDiv.textContent = message;
        } else if (type === 'register') {
            registerErrorDiv.textContent = message;
        }
    }

    // --- API Call Functions ---
    async function login(event) {
        event.preventDefault(); // Prevent default form submission
        clearErrorMessages();
        const username = loginUsernameInput.value.trim();
        const password = loginPasswordInput.value.trim();

        if (!username || !password) {
            displayError('login', 'Username and password are required.');
            return;
        }

        try {
            const response = await fetch(`${API_BASE_URL}/calculator/api/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
                mode: 'cors'
            });

            const data = await response.json(); // Try to parse JSON regardless of status

            if (!response.ok) {
                throw new Error(data.message || 'Login failed'); // Use server message if available
            }

            localStorage.setItem('token', data.token);
            showCalculatorView();
            authForm.reset(); // Clear form fields on success
        } catch (error) {
            console.error('Login Error:', error);
            displayError('login', `Login failed: ${error.message}`);
        }
    }

    async function register(event) {
        event.preventDefault(); // Prevent default form submission
        clearErrorMessages();
        const username = registerUsernameInput.value.trim();
        const password = registerPasswordInput.value.trim();

        if (!username || !password) {
            displayError('register', 'Username and password are required.');
            return;
        }
        // Basic password validation (example)
        if (password.length < 6) {
            displayError('register', 'Password must be at least 6 characters long.');
            return;
        }


        try {
            const response = await fetch(`${API_BASE_URL}/calculator/api/register`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
                mode: 'cors'
            });

            const data = await response.json(); // Try to parse JSON regardless of status

            if (!response.ok) {
                 throw new Error(data.message || 'Registration failed'); // Use server message
            }

            alert('Registration successful! Please log in.'); // Keep alert for success feedback
            showLoginView();
            registerForm.reset(); // Clear form fields on success

        } catch (error) {
            console.error('Registration Error:', error);
            displayError('register', `Registration failed: ${error.message}`);
        }
    }

    function logout() {
        localStorage.removeItem('token');
        showLoginView();
    }

    // --- Calculator Functions ---
    function appendToDisplay(value) {
        // Avoid starting with operators (except minus) or multiple operators
        const lastChar = display.value.slice(-1);
        const operators = "+-*/";
        if (operators.includes(value) && (operators.includes(lastChar) || display.value === '')) {
             if (value === '-' && display.value === '') { // Allow starting with minus
                display.value += value;
             }
             return; // Prevent adding operator if last char is operator or display is empty
        }
         // Prevent multiple decimal points in a number segment
        const parts = display.value.split(/[\+\-\*\/]/);
        if (value === '.' && parts[parts.length - 1].includes('.')) {
            return;
        }

        display.value += value;
    }

    function clearDisplay() {
        display.value = '';
    }

    function calculate() {
        try {
            // WARNING: eval() can be dangerous if the input isn't controlled.
            // For a simple calculator like this, it might be acceptable,
            // but in real-world applications, consider parsing and calculating manually.
            const result = eval(display.value);
             if (result === Infinity || result === -Infinity || isNaN(result)) {
                 display.value = 'Error';
             } else {
                // Optional: round to a certain number of decimal places
                display.value = parseFloat(result.toFixed(10)); // Fix floating point issues like 0.1+0.2
             }
        } catch (e) {
            display.value = 'Error';
        }
    }

    // --- Event Listeners ---
    authForm.addEventListener('submit', login);
    registerForm.addEventListener('submit', register);

    showRegisterButton.addEventListener('click', showRegisterView);
    showLoginButton.addEventListener('click', showLoginView);
    logoutButton.addEventListener('click', logout);

    // Add event listeners for all calculator buttons
    calculatorButtons.forEach(button => {
        button.addEventListener('click', () => {
            const value = button.textContent; // Get button text content

            if (button.classList.contains('clear')) {
                clearDisplay();
            } else if (button.classList.contains('equals')) {
                calculate();
            } else {
                appendToDisplay(value);
            }
        });
    });

    // --- Initial State ---
    // Check if a token exists on load - could redirect to calculator if valid
    // For now, just default to login view
    if (localStorage.getItem('token')) {
         // Optional: You could add a check here to verify the token with the backend
         // If valid token -> showCalculatorView()
         // If invalid/expired -> localStorage.removeItem('token'); showLoginView();
         showCalculatorView(); // Simple approach: assume token means logged in
    } else {
        showLoginView(); // Show login by default
    }

}); // End DOMContentLoaded
