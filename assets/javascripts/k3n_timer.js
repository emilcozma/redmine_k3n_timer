var K3nTimer = function () {

	var cleanState = {
		started: null,
		comment: null,
		descr: null,
		lastActivity: null,
		nagged: null,
		userLastSeen: Date.now()
	};

	var beta = localStorage.getItem('k3n_timer') === 'beta';

	var shortLanguage = 'en';
	var language = 'en-GB';

	var idleThreshold       =  1 * 60;
	var idleStartThreshold  =  5 * 60;
	var idleStopThreshold   = 45 * 60;
	var idleSleepThreshold  = 30 * 60;

	var state;
	var stateKey = 'k3n_timer';
	var button   = $('<button class="k3n_timer_button"></button>');
	var dialog   = null;
	var forgotDialog   = null;

	function setLanguage(language){
		switch(language) {
			case 'de':
				this.language = 'de-DE';
				break;
			default:
				this.language = 'en-GB';
		}
		this.shortLanguage = language;
	}

	function setPlugin(plugin){
		this.plugin = plugin
	}
	
	function setCurrentTimer(timer){
		this.timer = timer
	}

	function setLang(lang){
		if (this.lang === undefined || this.lang === null) {
			this.lang = ['k3n_timer'];
		}
		this.lang['k3n_timer'] = lang
	}
	
	function setUserId(user){
		this.user_id = user;
		stateKey = 'k3n_timer/' + this.user_id;
	}

	function setApiKey(key){
		this.api_key = key;
	}

	function setApiUrl(url){
		this.timelog_url = url;
	}
	
	function updateUI() {
		var enabled = false;
		var title   = null;

		if (state.started) {
			enabled = true;
			var startDate = new Date(state.started);
			title   = t('logging_since', { descr: state.descr, time: startDate.toLocaleDateString(this.language, { weekday:'long', year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric'}) });
		}

		if (!this.api_key) {
			title = t('need_rest_api');
		} else {
			enabled = true;
		}
		if(!state.started){
			button.text(state.started ? t('recording').replace('[xx:xx:xx]', '') : (this.timer.total_count ? this.timer.total_time : t('start'))).attr('title', title).attr('disabled', !enabled);
		}
		button.attr('title', title);
	}

	function loadState() {
		state = JSON.parse(localStorage.getItem(stateKey) || JSON.stringify(cleanState));
		updateUI();
		var startDate = new Date(state.started);
		var currentDate = new Date(Date.now());
		//check if the day was changed from starting
		if (state.started) {
			if(startDate.toLocaleDateString(this.language, { year: 'numeric', month: 'numeric', day: 'numeric'}) != currentDate.toLocaleDateString(this.language, { year: 'numeric', month: 'numeric', day: 'numeric'})){
				openForgotDialog();
			}
		}
		if (!state.started) {
			button.removeClass('counting');
		} else {
			button.addClass('counting');
		}
	}

	function clearState() {
		state = JSON.parse(JSON.stringify(cleanState));
		saveState();
	}

	function saveState() {
		localStorage.setItem(stateKey, JSON.stringify(state));
		updateUI();
		if (!state.started) {
			button.removeClass('counting');
		} else {
			button.addClass('counting');
		}
	}

	$(window).bind('storage', function (event) {
		if (event.originalEvent.key === stateKey) {
			loadState();

			if (!state.started && dialog) {
				dialog.dialog('close');
			}
		}
	});

	function userDetected() {
		var now  = Date.now();
		var last = state.userLastSeen;
		if (now - last > idleThreshold * 1000 && currentIssueVisible()) {
			// User returned to view current issue
			activityDetected();
		}
		state.userLastSeen = now;
		if (now - last > 1000) {
			saveState();
		}
	}

	function activityDetected(ts) {
		state.lastActivity = ts || Date.now();
		saveState();
	}

	function currentIssueVisible() {
		return state.started &&
			  (state.project && this.project && state.project.id === this.project.id) &&
			  (!state.issue  || this.issue   && state.issue.id   === this.issue.id);
	}

	function checkIdleTimeout() {
		var now = Date.now();
		// User idle handling
		var idle = (now - state.userLastSeen) / 1000;
		if (!state.lastActivity) {
			activityDetected();
		} else if (idle > idleSleepThreshold) {
			// * Once user is *not* working, set activity to time when user returns
			// * Once user *is* working, set activity to time when user left
			activityDetected(state.started ? state.userLastSeen : Date.now());
		} else if (!state.started /* Not working */ &&
				 now - state.lastActivity > 4 * 3600 * 1000 /* Last activity > 4 hrs ago */ &&
				 new Date(state.lastActivity).getDate() != new Date().getDate() /* Not today */) {
			activityDetected();
		}
		// Activity reminder handling
		var inactive = (now - state.lastActivity) / 1000;
		if (!state.nagged && state.started && inactive > idleStopThreshold) {
			state.nagged = now;
			saveState();
			displayNotification(t('should_punch_out_title'), t('should_punch_out_message', { descr: state.descr, time: toTime(state.lastActivity) }), function () {
				openDialog();
			});
		} else if (!state.nagged && !state.started && idle < idleThreshold /* not idle */ && inactive > idleStartThreshold) {
			state.nagged = now;
			saveState();
			displayNotification(t('should_punch_in_title'), t('should_punch_in_message', { time: toTime(state.lastActivity) }));
		}
	}

	function showTimer() {
		if(state.started){
			var now = Date.now();
			// get total seconds between the times
			var currentMiliSeconds = (parseInt(this.timer.total_time_hours) * 3600 + parseInt(this.timer.total_time_minutes) * 60 + parseInt(this.timer.total_time_seconds)) * 1000;
			var delta = Math.abs(now - state.started + currentMiliSeconds) / 1000;
			// calculate (and subtract) whole days
			var days = Math.floor(delta / 86400);
			delta -= days * 86400;
			// calculate (and subtract) whole hours
			var hours = Math.floor(delta / 3600) % 24;
			delta -= hours * 3600;
			// calculate (and subtract) whole minutes
			var minutes = Math.floor(delta / 60) % 60;
			delta -= minutes * 60;
			// what's left is seconds
			var seconds = Math.floor(delta % 60);  // in theory the modulus is not required
			var text = t('recording').replace('[xx:xx:xx]', pad((days * 24 + hours), 2) + ':' + pad(minutes, 2) + ':' + pad(seconds, 2));
			button.text(text);
		}
		var sT = setTimeout(function() { showTimer() }, 500);
	}

	function pad(n, width, z) {
	  z = z || '0';
	  n = n + '';
	  return n.length >= width ? n : new Array(width - n.length + 1).join(z) + n;
	}

	function start() {
		if (!this.api_key) {
			alert(t('need_rest_api'));
		} else {
			state = {
				started:      Date.now(),
				comment:      '',
				nagged:       null
			}
			saveState();
		}
	}

	function commit(stopped) {
		var comment = timeComment(state.comment, state.started, stopped);
		var startDate = new Date(state.started);
		$.ajax(this.timelog_url, {
			method: 'POST',
			data: JSON.stringify({
				k3n_timer: {
					hours: (stopped - state.started) / 1000 / 60 / 60,
					spent_on: startDate.getFullYear() + '-' + ("0" + (startDate.getMonth() + 1)).slice(-2) + '-' + ("0" + startDate.getDate()).slice(-2),
					start_time: toTime(state.started),
					end_time: toTime(stopped),
					description: state.comment,
					comments: comment
				}
			}),
			contentType: 'application/json',
			headers: {
				'X-Redmine-API-Key': this.api_key,
			},
		})
		.done(function (response) {
			window.location.href = response.redirect_url;
			clearState();
		})
		.fail(function ($xhr) {
			console.log(arguments);
			alert(t('submit_failed', { error: $xhr.responseJSON && $xhr.responseJSON.errors }));
		});
	}

	function discard() {
		clearState();
	}

	function openDialog() {
		if(!forgotDialog){
			var startDate = new Date(state.started);
			var currentDate = new Date(Date.now());
			//check if the day was changed from starting
			if(startDate.toLocaleDateString(this.language, { year: 'numeric', month: 'numeric', day: 'numeric'}) != currentDate.toLocaleDateString(this.language, { year: 'numeric', month: 'numeric', day: 'numeric'})){
				openForgotDialog();
			} else {
				if (dialog) {
					dialog.dialog('destroy');
				}
				var form       = $('<form class="k3n_timer_form"/>').submit(false);
				[
					$('<fieldset/>').append($('<legend/>').text(t('details'))).append(
						$('<table/>').append(
							$('<tr/>').append($('<td/>').text(t('time')), $('<td/>').append(
								$('<span id="k3n_timer_start" class="time" />')
									.text(toTime(state.started)),
								' – ',
								$('<span id="k3n_timer_stop" class="time" />')
									.text(toTime(Date.now()))
							))
						)
					),
					$('<fieldset/>').append($('<legend/>').text(t('comment')).append('')).append(
						$('<textarea id="k3n_timer_comment" autocomplete="off" autofocus rows="4" style="width:100%" />').attr('value', state.comment)
							.change(function () {
								state.comment = this.value;
								saveState();
								enableOrDisableCommit();
							})
							.keyup(function (event) {
								if (event.keyCode === 13) {
									state.started = updateTime(state.started, 'k3n_timer_start');
									commit(updateTime(Date.now(), 'k3n_timer_stop'));
									dialog.dialog('close');
									activityDetected();
								}
							})
					)
				].forEach(function (elem) {
					form.append(elem);
				});

				dialog = form.dialog({
					dialogClass: 'k3n_timer_dialog',
					position: { my: 'right top', at: 'right bottom', of: button },
					width: 450,
					draggable: false,
					modal: true,
					hide: 200,
					show: 200,
					title: t('plugin_name'),
					open: function () { // Hack to remove black line in Safari
						if (/Apple/.test(window.navigator.vendor)) {
							$('.k3n_timer_dialog').each(function (idx, elem) {
								elem.style.background = window.getComputedStyle(elem).backgroundColor;
							});
						}
					},
					buttons: [
						{
							text: t('commit'), icons: { primary: 'ui-icon-clock' }, id: 'k3n_timer_commit', click: function () {
								state.started = updateTime(state.started, 'k3n_timer_start');
								commit(updateTime(Date.now(), 'k3n_timer_stop'));
								dialog.dialog('close');
								activityDetected();
							}
						},
						{
							text: t('discard'), icons: { primary: 'ui-icon-trash' }, click: function () {
								discard();
								dialog.dialog('close');
								activityDetected();
							}
						},
						{
							text: t('close'), icons: { primary: 'ui-icon-close' }, click: function () {
								state.started = updateTime(state.started, 'k3n_timer_start');
								saveState();
								dialog.dialog('close');
								activityDetected();
							}
						}
					]
				});
			}
		}
	}

	function openForgotDialog() {
		if (forgotDialog) {
			forgotDialog.dialog('destroy');
		}
		var form       = $('<form class="k3n_timer_form"/>').submit(false);
		[
			$('<p class="forgot-info-text"/>').html(t('forgot_keeen_out_text', {'commit': t('commit'), 'start': '<b>' + toDate(state.started) + '</b>', 'discard' : t('discard')})),
			$('<fieldset/>').append($('<legend/>').text(t('details'))).append(
				$('<table/>').append(
					$('<tr/>').append($('<td/>').text(t('time')), $('<td/>').append(
						$('<span id="f_k3n_timer_start" class="time" />')
							.text(toTime(state.started)),
						' – ',
						$('<input type="text" id="f_k3n_timer_stop" class="input-time" size="8" />')
							.val(getDefaultForgetEndTime()).timepicker({
													timeFormat: 'HH:mm:ss',
													defaultValue: getDefaultForgetEndTime(),
													minTime: toTime(Math.ceil(state.started / (1000 * 60)) * 1000 * 60),
													regional: this.shortLanguage
											})
					))
				)
			),
			$('<fieldset/>').append($('<legend/>').text(t('comment')).append('')).append(
				$('<input id="k3n_timer_comment" type="text" autocomplete="off" autofocus />').attr('value', state.comment)
					.change(function () {
						state.comment = this.value;
						saveState();
						enableOrDisableCommit();
					})
					.keyup(function (event) {
						if (event.keyCode === 13) {
							state.started = updateTime(state.started, 'f_k3n_timer_start');
							commit(updateTime(getCommitDateTime(), 'f_k3n_timer_stop'));
							forgotDialog.dialog('close');
							activityDetected();
						}
					})
			)
		].forEach(function (elem) {
			form.append(elem);
		});

		forgotDialog = form.dialog({
			dialogClass: 'k3n_timer_forgot_dialog',
			position: { my: "center", at: "center", of: window },
			width: 450,
			draggable: false,
			modal: true,
			hide: 200,
			show: 200,
			title: t('plugin_name'),
			open: function () { // Hack to remove black line in Safari
				if (/Apple/.test(window.navigator.vendor)) {
					$('.k3n_timer_forgot_dialog').each(function (idx, elem) {
						elem.style.background = window.getComputedStyle(elem).backgroundColor;
					});
				}
			},
			buttons: [
				{
					text: t('commit'), icons: { primary: 'ui-icon-clock' }, id: 'k3n_timer_commit', click: function () {
						state.started = updateTime(state.started, 'f_k3n_timer_start');
						commit(updateTime(getCommitDateTime(), 'f_k3n_timer_stop'));
						forgotDialog.dialog('close');
						activityDetected();
					}
				},
				{
					text: t('discard'), icons: { primary: 'ui-icon-trash' }, click: function () {
						discard();
						forgotDialog.dialog('close');
						activityDetected();
					}
				},
				{
					text: t('close'), icons: { primary: 'ui-icon-close' }, click: function () {
						state.started = updateTime(state.started, 'f_k3n_timer_start');
						saveState();
						forgotDialog.dialog('close');
						activityDetected();
					}
				}
			]
		});
	}

	function getDefaultForgetEndTime(){
		var normalWorkingHoursPerDay = 8;
		var maxWorkingHour = 24;
		var startDate = new Date(state.started);
		var endDate = startDate;
		if(startDate.getHours() + normalWorkingHoursPerDay > (maxWorkingHour - 1)){
			endDate.setHours((maxWorkingHour - 1), 59, 59);
		} else {
			endDate.setHours(startDate.getHours() + normalWorkingHoursPerDay);
		}
		return toTime(endDate.getTime());
	}

	function getCommitDateTime() {
		var startDate = new Date(state.started);
		var endTime = $('#f_k3n_timer_stop').val();
		var time = endTime.match(/(\d+)(?::(\d\d))?(?::(\d\d))?\s*(p?)/i);
		var endDate = startDate;
		endDate.setHours(time[1], time[2], time[3]);
		return endDate.getTime();
	}

	function toDate(date) {
		date = date instanceof Date ? date : new Date(date);
		return date.toLocaleDateString(this.language, {year: 'numeric', month: 'numeric', day: 'numeric'});
	}

	function toTime(date) {
		date = date instanceof Date ? date : new Date(date);
		return date.toLocaleTimeString(this.language, {hour: 'numeric', minute: 'numeric', second: 'numeric'});
	}

	function timeComment(comment, started, stopped) {
		return (comment + ' [' + toTime(started) + '–' + toTime(stopped) + ']').trim();
	}

	function parseTime(time) {
		var parsed = /^(\d*(\.\d+)?)$|^((\d+)[:h])?((\d+)m?)?$/.exec(time);
		return parsed && parsed[1] ? parseFloat(parsed[1]) :
			   parsed ? parseInt(parsed[4] || 0) + parseInt(parsed[5].substring(0, 2) || 0) / 60 :
			   null;
	}

	function parseTimeComment(comment, refdate) {
		refdate = refdate || Date.now();
		function toTimestamp(hours) {
			return new Date(refdate).setHours(0, hours * 60, 0, 0);
		}
		var timecomment = /(.*)\[([0-9]{2}:[0-9]{2})[-–]([0-9]{2}:[0-9]{2})\]\s*$/.exec(comment);
		return timecomment && {
			comment: timecomment[1].trim(),
			started: toTimestamp(parseTime(timecomment[2])),
			stopped: toTimestamp(parseTime(timecomment[3]))
		};
	}

	function enableOrDisableCommit() {
		var disabled = false;
		$('#k3n_timer_commit').attr('disabled', disabled).toggleClass('ui-state-disabled', disabled);
	}

	function updateTime(ts, input) {
		var hhmm = /^([0-9]{2}):([0-9]{2}):([0-9]{2})$/.exec(document.getElementById(input).textContent);
		if (hhmm) {
			var date = new Date(ts);
			date.setHours(hhmm[1], hhmm[2], hhmm[3]);
			ts = date.getTime();
		}
		return ts;
	}

	function displayNotification(title, message, onClickHandler) {
		if (!window.Notification) {
			if (confirm(title + ': ' + message) && onClickHandler) {
				onClickHandler();
			}
		}
		else if (Notification.permission === 'granted') {
			var entry = new Notification(title, { body: message });
			onClickHandler && $(entry).click(onClickHandler);
		}
		else if (Notification.permission !== 'denied') {
			Notification.requestPermission(function (permission) {
				if (permission === 'granted') {
					displayNotification(title, message, onClickHandler);
				}
			});
		}
	}

	function t(key, props) {
		return (this.lang['k3n_timer'][key] || key).replace(/%{([^}]+)}/g, function (_, prop) {
			return String(Object(props)[prop]);
		});
	}

	function init(){
		// Insert punch button
		button.click(function () {
			if (!state.started) {
				start();
			} else {
				if(forgotDialog){
					openForgotDialog()
				} else {
					openDialog();
				}
			}
			activityDetected();
		});
		loadState();
		//$('#quick-search').prepend(button);
		$('#loggedas').after(button);
		// Activate nag requesters
		setInterval(checkIdleTimeout, 1000);
		showTimer();
		document.addEventListener && document.addEventListener('visibilitychange', function () {
			if (!document.hidden) {
				userDetected();
			}
		}, false);
		$(window).focus(userDetected);
		$(window).keydown(userDetected);
		$(window).click(userDetected);
		$(window).scroll(userDetected);
		$(window).mousemove(userDetected);
		userDetected();
		if (currentIssueVisible()) {
			// The issue/project we're logging to was just (re)loaded
			activityDetected();
		}
		// Curry "Edit time" fields
		var time_entry_hours    = $('form.edit_time_entry input#time_entry_hours');
		var time_entry_comments = $('form.edit_time_entry input#time_entry_comments');
		if (time_entry_hours.length == 1 && time_entry_comments.length == 1) {
			time_entry_hours.on('input', function() {
				var hr = parseTime(this.value)
				var tc = parseTimeComment(time_entry_comments.val());
				if (hr !== null && tc) {
					time_entry_comments.val(timeComment(tc.comment, tc.started, tc.started + hr * 3600000));
				}
			});
			time_entry_comments.on('input', function() {
				var tc = parseTimeComment(this.value);
				if (tc) {
					time_entry_hours.val(((tc.stopped - tc.started) / 3600000).toFixed(2));
				}
			});
		}
	}
	return {
		setPlugin: function(plugin){
			setPlugin(plugin);
		},
		setCurrentTimer: function(timer){
			setCurrentTimer(timer);
		},
		setLang: function(lang){
			setLang(lang);
		},
		setUserId: function(user){
			setUserId(user);
		},
		setApiKey: function(key){
			setApiKey(key);
		},
		setApiUrl: function(url){
			setApiUrl(url);
		},
		setLanguage: function(language){
			setLanguage(language);
		},
        init: function () {
			init();
		}
	}
}();
