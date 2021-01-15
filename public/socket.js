document.addEventListener("DOMContentLoaded", function() {
    const socket = new WebSocket('ws://' + location.host + '/state');
    socket.addEventListener('open', function (event) {
	socket.send('Hello!');
    });
    socket.addEventListener('message', function (event) {
	try {
	    var t = JSON.parse(event.data);
	    console.log(t);
	    var s = document.querySelector('[data-switch-id="' + t.ip + '"]');
	    if (s && t.state == 1){
		s.classList.add('on')
		s.classList.remove('off')
	    } else if (s && t.state == 0){
		s.classList.add('off')
		s.classList.remove('on')
	    } else if (s) {
		s.classList.remove('off')
		s.classList.remove('on')
		s.classList.add('inactive')
	    }
	} catch(e){
	    console.log('Message from server ', event.data);
	    console.log(e);
	}
    });
    
});
