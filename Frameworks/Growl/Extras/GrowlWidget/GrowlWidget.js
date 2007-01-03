function setup() {
	return 0;
}

function appendMessage(html) {
	//Append the new message to the bottom of our block
	var notifications = document.getElementById("Notifications");
	var range = document.createRange();
	range.selectNode(notifications);
	var documentFragment = range.createContextualFragment(html);
	notifications.appendChild(documentFragment);
}

function setMessage(html) {
	//Append the new message to the bottom of our block
	var notifications = document.getElementById("Notifications");
	var range = document.createRange();
	range.selectNode(notifications);
	var documentFragment = range.createContextualFragment(html);
	var child = notifications.firstChild;
	if (child) {
		notifications.replaceChild(documentFragment, child);
	} else {
		notifications.appendChild(documentFragment);
	}
}
