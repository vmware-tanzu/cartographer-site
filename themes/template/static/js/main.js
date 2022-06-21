"use strict";

function mobileNavToggle() {
    var menu = document.getElementById('mobile-menu').parentElement;
    menu.classList.toggle('mobile-menu-visible');
}

function docsVersionToggle() {
    var menu = document.getElementById('dropdown-menu');
    menu.classList.toggle('dropdown-menu-visible');
}

window.onclick = function(event) {
    var 
        target = event.target,
        menu = document.getElementById('dropdown-menu')
    ;

    if(!target.classList.contains('dropdown-toggle')) {
        menu.classList.remove('dropdown-menu-visible');
    }
}

function addCopyButtons(clipboard) {
    document.querySelectorAll('pre > code').forEach(function (codeBlock) {
        var button = document.createElement('button');
        button.className = 'copy';
        button.type = 'button';
        button.innerText = 'Copy';

        button.addEventListener('click', function () {
            clipboard.writeText(codeBlock.innerText).then(function () {
                /* Chrome doesn't seem to blur automatically,
                   leaving the button in a focused state. */
                button.blur();

                button.innerText = 'Copied!';

                setTimeout(function () {
                    button.innerText = 'Copy';
                }, 2000);
            }, function (error) {
                button.innerText = 'Error';
            });
        });

        codeBlock.parentNode.prepend(button);
    });
}
