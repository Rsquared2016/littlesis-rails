var utility = {};

/**
 * 
 * @param {Integer} id
 * @param {String} name
 * @param {String} ext
 * @returns {String} 
 */
utility.entityLink = function(id, name, ext) {
  var url = 'https://littlesis.org/';
  if (ext.toLowerCase() === 'person') {
    url += 'person/';
  } else {
    url += 'org/';
  }
  url += (id + '/'  + name.replace(' ', '_'));
  return url;
};


/**
 * 
 * @param {integer} x
 * @param {array} to_exclude
 * @returns {array} 
 */
utility.range = function(x, toExclude) {
  var range = Array.apply(null, Array(x)).map(function (_, i) {return i;});
  if (Array.isArray(toExclude)) {
    return range.filter(function(x) { return !toExclude.includes(x); });
  } else {
    return range;    
  }
};


/**
 * Random String of digits
 * @param {integer} n number of digits
 * @returns {String}
 */
utility.randomDigitStringId = function(n) {
  if (typeof n === 'undefined') {
    n = 10;
  }
  else if (n > 14 || n < 1) {
    throw  "randomDigitStringId() can return at most 14 digits";
  }
  return Math.random().toString().slice(2, (2 + n));
};

/**
 * looks up entity info stored in #entity-info div 
 * @param {string} key
 * @returns {string} 
 */
utility.entityInfo = function(key) {
  return document.getElementById('entity-info').dataset[key];
};

/**
 * Relationship categories
 */
utility.relationshipCategories = [
  "",
  "Position",
  "Education",
  "Membership",
  "Family",
  "Donation/Grant",
  "Service/Transaction",
  "Lobbying",
  "Social",
  "Professional",
  "Ownership",
  "Hierarchy",
  "Generic"
];

/**
 * Extension Definition / Entity Types
 */
utility.extensionDefinitions = {
  "1": "Person",
  "2": "Organization",
  "3": "Political Candidate",
  "4": "Elected Representative",
  "5": "Business",
  "6": "Government Body",
  "7": "School",
  "8": "Membership Organization",
  "9": "Philanthropy",
  "10": "Other Not-for-Profit",
  "11": "Political Fundraising Committee",
  "12": "Private Company",
  "13": "Public Company",
  "14": "Industry/Trade Association",
  "15": "Law Firm",
  "16": "Lobbying Firm",
  "17": "Public Relations Firm",
  "18": "Individual Campaign Committee",
  "19": "PAC",
  "20": "Other Campaign Committee",
  "21": "Media Organization",
  "22": "Policy/Think Tank",
  "23": "Cultural/Arts",
  "24": "Social Club",
  "25": "Professional Association",
  "26": "Political Party",
  "27": "Labor Union",
  "28": "Government-Sponsored Enterprise",
  "29": "Business Person",
  "30": "Lobbyist",
  "31": "Academic",
  "32": "Media Personality",
  "33": "Consulting Firm",
  "34": "Public Intellectual",
  "35": "Public Official",
  "36": "Lawyer",
  "37": "Couple",
  "38": "Academic Research Institute",
  "39": "Government Advisory Body",
  "40": "Elite Consensus Group"
};

/**
 * Returns an nested array of [ display, fieldname, type ] 
 * possible types: 'text', 'date', 'triboolean', 'boolean', 'money', 'number'
 * @param {number} category
 */
utility.relationshipDetails = function(category) {
  // reusable fields that are common to multiple categories
  var title = ['Title', 'description1', 'text'];
  var isCurrent = ['Is current?', 'is_current', 'triboolean'];
  var startDate = ['Start date', 'start_date', 'date' ];
  var endDate = ['End date', 'end_date', 'date' ];
  var type = ['Type', 'description1', 'text'];
  var amount = ['Amount', 'amount', 'money'];
  var goods = ['Goods', 'goods', 'text'];
  var d1 = ['entity 1 is __ of entity 2', 'description1', 'text'];
  var d2 = ['entity 2 is __ of entity 1', 'description2', 'text'];
      
  switch(category) {
  case 1: // postition
    return [
      title, isCurrent, startDate, endDate,
      ['Board member?', 'is_board', 'boolean' ],
      ['Executive?', 'is_executive', 'boolean' ],
      ['Compensation','compensation', 'money' ]
    ];
  case 2: // eduction
    return [
      type, startDate, endDate,
      ['Degree', 'degree', 'text'],
      ['Field', 'education_field', 'text'],
      ['Dropout?', 'is_dropout', 'boolean']
    ];
  case 3: // members
    return [
      title, startDate, endDate, isCurrent,
      ['Membership Dues', 'dues', 'money']
    ];
  case 4: // family
    return [ d1, d2, startDate, endDate, isCurrent ];
  case 5: // donation
    return [ type, amount, startDate, endDate, isCurrent, goods ];
  case 6: // transaction
    return [ d1, d2, amount, startDate, endDate, isCurrent, goods ];
  case 7: // lobby
    throw 'Lobbying relationships are not currently supposed by the bulk add tool';
  case 8: // social
    return [ d1, d2, startDate, endDate, isCurrent ];
  case 9: // professional
    return [ d1, d2, startDate, endDate, isCurrent ];
  case 10: // ownership
    return [ 
      title, startDate, endDate, isCurrent,
      [ 'Percent Stake', 'percent_stake', 'number'],
      [ 'Shares Owned', 'shares', 'number']
    ];
  case 11: // hierarchy
    return [ d1, d2, startDate, endDate, isCurrent ];
  case 12: // generic
    return [ d1, d2, startDate, endDate, isCurrent ];
  default:
    throw 'Invalid relationship category. It must be a number between 1 and 12';
  }
};

utility.validDate = function(str) {
  if (str.length === 4 && Boolean(str.match(/[0-9]{4}/))) {
    return true;
  }
  var date = str.split('-');
  if (date.length !== 3
      || date[0].length !== 4
      || date[1].length !== 2
      || date[2].length !== 2
      || Number(date[1]) > 12
      || Number(date[2]) > 31)
  {
    return false;
  }
  return true;
};

/**
   Simple url validation. Tests if it begins with 'http://' or 'https://' and is
   followed by at least one character followed by a dot followed by another character. 
   
   So yes, http://1.blah is a valid url according to these standards...we could go crazy with the regexs...https://mathiasbynens.be/demo/url-regex...but this is FINE
*/
utility.validURL = function(str) {
    var pattern = RegExp('^(https?:\/\/)(.+)[\.]{1}.+$');
    return pattern.test(str);
};


utility.validPersonName = function(str){
  // see specs for documentation of this lovely little regex
  //return Boolean(str.match(/^[a-z,.'-]+\s[a-z,.'-]+(\s[a-z,.'-]+)?$/i));
  return Boolean(str.match(/^[^0-9\s]+\s[^0-9\s]+(\s[^0-9\s]+){0,3}$/i));

};

/**
 * Determines if the browser has the ability to open and read files
 * @returns {Boolean} 
 */
utility.browserCanOpenFiles = function() {
    return (window.File && window.FileReader && window.FileList && window.Blob);
};


// STRING UTILITIES

utility.capitalize = function(str){
  // NOTE (@aguestuser):
  // opted for util function isntead of polyfilling String.prototype
  // b/c I did the latter and it produced a fatal namespace collision with datatables.js
  return str.slice(0,1).toUpperCase() + str.slice(1);
};

utility.formatIdSelector = function(str) {
  if (str.slice(0,1) === '#') {
    return str;
  } else {
    return '#' + str;
  }
};

// OBJECT UTILITIES

// Object -> Any
utility.get = function(obj, key) {
  var entry = utility.isObject(obj) && Object.getOwnPropertyDescriptor(obj, key);
  return entry ? entry.value : undefined;
};


// Object, [String] -> Any
utility.getIn = function(obj, keys){
  return keys.reduce(
    function(acc, key){ return utility.get(acc, key); },
    obj
  );
};

// Object, String, Any -> Object
utility.set = function(obj, key, value){
  var _obj = Object.assign({}, obj);
  return Object.defineProperty(_obj, key, {
    configurable: true,
    enumerable: true,
    writeable: true,
    value: value
  });
};

// Object, [String], Any -> Object
utility.setIn = function(obj, keys, value){
  if (keys.length === 0) {
    return value;
  } else {
    return utility.set(
      obj,
      keys[0],
      utility.setIn(
        utility.get(obj, keys[0]),
        keys.slice(1),
        value
      )
    );
  }
};

// Object, String -> Object
utility.delete = function(obj, keyToDelete){
  return Object.keys(obj).reduce(
    function(acc, key){
      return key === keyToDelete ?
        acc :
        utility.set(acc, key, utility.get(obj, key));
    },
    {}
  );
};

// Object, [String] -> Object
utility.deleteIn = function(obj, keys){
  var leafPath = keys.slice(0, -1);
  var leafNode = utility.getIn(obj, leafPath);
  return !(leafPath && leafNode) ?
    obj :
    utility.setIn(
      obj,
      leafPath,
      utility.delete(leafNode, keys.slice(-1)[0])
    );
};

// [Record] -> { [String]: Record}
utility.normalize = function(arr){
  // turn an array of records into a lookup table of records by id
  // see https://github.com/paularmstrong/normalizr
  return arr.reduce(
    function(acc, item){ return utility.set(acc, item.id, item); },
    {}
  );
};

// Object -> Object
utility.stringifyValues = function(obj){
  // stringify all values except booleans
  // mostly for use in deserializing JSON
  return Object.keys(obj).reduce(
    function(acc, k){
      var val = utility.get(obj, k);
      return utility.set(
        acc,
        k,
        // only stringify non-boolean existy vals
        (val === true || val === false) ? val : val && String(val)
      );
    },
    {}
  );
};


/**
 * Returns object with only the permitted keys
 * 
 * @param {Object} obj
 * @param {Array[String]} keys
 * @returns {Object}
 */
utility.pick = function(obj, keys) {
  var result = {};
  keys.forEach(function(k) {
    result[k] = obj[k];
  });
  return result;
};

/**
 * Returns object without rejected set of keys
 * 
 * @param {Object} obj
 * @param {Array[String]} keys
 * @returns {Object}
 */
utility.omit = function(obj, keys) {
  var result = Object.assign({}, obj);
  keys.forEach(function(k) {
    delete result[k];
  });
  return result;
};


// Object -> Boolean
utility.exists = function(obj){
  return obj !== undefined && obj !== null;
};

// ?Object -> Boolean
utility.isObject = function(value){
  var type = typeof value;
  return value != null && (type == 'object' || type == 'function');
};

// Object -> Boolean
utility.isEmpty = function (obj){
  return !Boolean(obj) || !Object.keys(obj).length;
};


// Browser/DOM Utilities

// JQueryNode -> JQueryNode
utility.appendSpinner = function(element){
  // leverage `sk-circle` classes in `assets/stylesheets/base/spin.css`
  // IMPORTANT: THIS MUST RETURN A VALUE OR CALLING CODE WILL BREAK!!!
  return $(element).append(
    $('<div>', { class: 'sk-circle' })
      .append($('<div>', { class: 'sk-circle1 sk-child' }))
      .append($('<div>', { class: 'sk-circle2 sk-child' }))
      .append($('<div>', { class: 'sk-circle3 sk-child' }))
      .append($('<div>', { class: 'sk-circle4 sk-child' }))
      .append($('<div>', { class: 'sk-circle5 sk-child' }))
      .append($('<div>', { class: 'sk-circle6 sk-child' }))
      .append($('<div>', { class: 'sk-circle7 sk-child' }))
      .append($('<div>', { class: 'sk-circle8 sk-child' }))
      .append($('<div>', { class: 'sk-circle9 sk-child' }))
      .append($('<div>', { class: 'sk-circle10 sk-child' }))
      .append($('<div>', { class: 'sk-circle11 sk-child' }))
      .append($('<div>', { class: 'sk-circle12 sk-child' }))
  );
};

// JQueryNode -> JQueryNode
utility.removeSpinner = function(element){
  // leverage `sk-circle` classes in `assets/stylesheets/base/spin.css`
  $(element).find('.sk-circle').remove();
  return $(element);
};

// String -> Void
utility.redirectTo = function(path){
  document.location.replace(path);
};


// -> Object
// Returns object representation of the query params of the current page url
utility.currentUrlParams = function() {
  if (window.location.search  === '') {
    return {};
  }

  return window.location.search
    .replace('?', '')
    .split('&')
    .reduce(function(acc, param) {
      var pair = param.split('=');
      return utility.set(acc, pair[0], pair[1]);
  }, {});
};


/**
 * Swaps two elements given their ids
 * Thanks to: https://stackoverflow.com/questions/10716986/swap-2-html-elements-and-preserve-event-listeners-on-them
 * @param {String} a ID 
 * @param {String} b ID
 */
utility.swapDomElementsById = function(aId, bId) {
  var a = document.getElementById(aId);
  var b = document.getElementById(bId);
  var temp = document.createElement("div");

  a.parentNode.insertBefore(temp, a);
  // move obj1 to right before obj2
  b.parentNode.insertBefore(a, b);
  // move obj2 to right before where obj1 used to be
  temp.parentNode.insertBefore(b, temp);
  // remove temporary marker node
  temp.parentNode.removeChild(temp);
};


/**
 * Swaps the value of two inputs given their ids
 * @param {String} a ID
 * @param {String} a ID
 */
utility.swapInputTextById = function(aId, bId) {
  var a = $(utility.formatIdSelector(aId));
  var b = $(utility.formatIdSelector(bId));
  var temp = a.val();
  a.val(b.val());
  b.val(temp);
};


/**
 * Creates new element with text content
 *
 * @param {String} tagName
 * @param {String} text
 * @returns {Element} 
 */
utility.createElementWithText = function(tagName, text) {
  var element = document.createElement(tagName);
  element.textContent = text;
  return element;
};


/**
 * This is a simple wrapper around document.createElement
 * There are three options:
 *   - tag (defaults to div)
 *   - id
 *   - class
 *   - text (textContent)
 *
 * @param {} options
 * @returns {Element}
 *
 */
utility.createElement = function(options) {
  var elementConfig = { "tag": 'div', "class": null, "id": null, "text": null};

  if (utility.isObject(options)) {
     Object.assign(elementConfig, options);
  }

  var element = document.createElement(elementConfig.tag);

  if (elementConfig['class']) {
    element.className = elementConfig['class'];
  }
  
  if (elementConfig['id']) {
    element.setAttribute('id', elementConfig['id']);
  }

  if (elementConfig['text']) {
    element.textContent = elementConfig['text'];
  }

  return element;
};


/**
 * Creates an <a> with the provided href and text
 *
 * @param {String} href
 * @param {String} text
 * @returns {Element}
 */
utility.createLink = function(href, text) {
  var a = document.createElement('a');
  a.href = href;
  if (text) {
    a.textContent = text;
  }
  return a;
};
