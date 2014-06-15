var headers = document.querySelectorAll('.policies > section > header');
for (var i = 0; i < headers.length; i++) {
    (function() {
        var el = headers[i];
        el.onclick = function() {
            var section = el.parentElement;
            if (section.classList.contains('expanded')) {
                section.classList.remove('expanded');
            } else {
                section.classList.add('expanded');
            }
        };
    })();
};

// Remove 300ms tap delay
window.addEventListener('load', function() { FastClick.attach(document.body); }, false);