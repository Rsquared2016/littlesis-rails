describe('tag module', function () {
  
  var allTags = [{
    name: 'oil',
    description: 'flows from pipes',
    id: 1
  },{
    name: 'nyc',
    description: 'center of the universe!',
    id: 2
  },{
    name: 'finance',
    description: 'banks got bailed out, we got sold out!',
    id: 3
  }];

  var divs = {
    control: "#tags-control",
    container: "#tags-container",
    edit: "#tags-edit-button"
  };

  var testDom =
        '<div id="test-dom">'  + 
          '<div id="tags-container"><br></div>' + 
          '<div id="tags-control">' + 
            '<button id="tags-edit-button"></button>' +
          '</div>' +
        '</div>'; 

  var divIds = Object.keys(divs).reduce(
    (acc, k) => Object.assign(acc, { [k]: divs[k].slice(1) }),
    {}
  );

  beforeEach(function(){
    $('body').append(testDom);
  });

  afterEach(function(){
    $('#test-dom').remove();
  });
  
  describe('tags store operations', function (){

    it('creates a tags data structure from input', function(){
      tags.init(allTags, [1], '/tag/endpoint', divs);
      expect(tags.get()).toEqual({
	all: {
	  1: allTags[0],
	  2: allTags[1],
          3: allTags[2]
	},
	current: ['1'],
        divs: divs,
        cache: { html: '<br>', tags: ['1']},
        endpoint: '/tag/endpoint'
      });
    });

    it('clears store upon initialization', function(){
      tags.init(allTags, [1], '/tag/endpoint', divs);
      expect(tags.get().current).toEqual(['1']);

      tags.init(allTags, [2], '/tag/endpoint', divs);
      expect(tags.get().current).toEqual(['2']);
    });

    it('adds a tag', () => {
      tags.init(allTags, [1], '/tag/endpoint', divs);
      tags.add(2);
      expect(tags.get().current).toEqual(['1', '2']);
    });

    it('retrives a tag id from a name', () => {
      tags.init(allTags, [], '/tag/endpoint', divs);
      expect(tags.getId('oil')).toEqual('1');
    });

    it('gets all available tags', () => {
      tags.init(allTags, [], '/tag/endpoint', divs);
      expect(tags.available()).toEqual(['1','2','3']);

      tags.init(allTags, [1], '/tag/endpoint', divs);
      expect(tags.available()).toEqual(['2','3']);
      
    });

    it('removes a tag', () => {
      tags.init(allTags, [1,2], '/tag/endpoint', divs);
      tags.remove(2);
      expect(tags.get().current).toEqual(['1']);
    });

    describe('side effects', () => {

      const stubbed = ['add', 'remove', 'render', 'post'];
      let spies;
      
      beforeEach(() => {
	spies = stubbed.reduce(
	  (acc, fn) => Object.assign(acc, { [fn]: spyOn(tags, fn) }),
	  {}
	);
      });
      
      it('updates the store and syncs w/ DOM & server', () => {
	tags.init(allTags, [2], '/tag/endpoint', divs);
	tags.update('add', 1);
	tags.update('remove', 2);
	
	expect(spies.add).toHaveBeenCalledWith(1);
	expect(spies.remove).toHaveBeenCalledWith(2);
	expect(spies.render).toHaveBeenCalled();
	expect(spies.post).toHaveBeenCalled();
      });
    }); //end  side effects
  });
  
  describe('displaying tags', function(){

    beforeEach(function(){
      tags.init(allTags, ['1','2'], '/tag/endpoint', divs);
    });

    it('shows nothing new when edit not clicked', () => {
      expect($('#tags-edit-list')).not.toExist();
    });

    it('shows edit mode when edit clicked', () => {
      $(divs.edit).trigger('click');
      expect($('#tags-edit-list')).toExist();
    });
  });

  describe('editing tags', function(){

    beforeEach(function(){
      tags.init(allTags, [1,2], '/tag/endpoint', divs);
    });

    describe('activating edit mode', () => {

      it('hides edit button in edit mode', () => {
        expect($('#tags-edit-button')).toBeVisible();
        $('#tags-edit-button').click();
        expect($('#tags-edit-button')).toBeHidden();
      });

      it('shows save and cancel buttons in edit mode', () => {
        expect($('#tags-save-button')).not.toBeVisible();
        expect($('#tags-cancel-button')).not.toBeVisible();

        $('#tags-edit-button').click();

        expect($('#tags-save-button')).toBeVisible();
        expect($('#tags-cancel-button')).toBeVisible();
      });
      
    });

    describe('using edit mode', () => {

      beforeEach(function(){
        $('#tags-edit-button').click();
      });

      it('shows an x inside tags that a user can remove', function(){
        expect($(`${divs.container} span.tag-remove-button`)).toHaveLength(2);
      });

      it('removes a tag when user clicks the remove button', function(){
        expect($(`#tags-edit-list li`)).toHaveLength(2);
        $($('.tag-remove-button')[0]).trigger('click');
        expect($(`#tags-edit-list li`)).toHaveLength(1);
      });

      it('shows a dropdown of valid, unused tags', () => {
        expect('#tags-select .tags-select-option').toHaveLength(1); // doesn't show already used tags
      });
      
      it('adds a tag when user selects if from dropdown', () => {
        expect($('#tags-edit-list').text()).not.toMatch('finance');
        $('#tags-select').val('finance').trigger('changed.bs.select');
        expect($('#tags-edit-list').text()).toMatch('finance');
      });
      
      it('restores old tags in view mode if user clicks cancel', () => {
        expect($(divs.container).html()).not.toEqual('<br>');
        $('#tags-cancel-button').click();
        expect($(divs.container).html()).toEqual('<br>');
      });

      it('restores old tags in edit mode if user clicks cancel', () => {
        expect($(`#tags-edit-list li`)).toHaveLength(2);

        $('#tags-select').val('finance').trigger('changed.bs.select');
        expect($(`#tags-edit-list li`)).toHaveLength(3);

        $('#tags-cancel-button').click();
        $('#tags-edit-button').click();
        expect($(`#tags-edit-list li`)).toHaveLength(2);
      });

      it('restores view-mode controls if user clicks cancel', () =>{
        expect($('#tags-save-button')).toBeVisible();
        expect($('#tags-cancel-button')).toBeVisible();
        expect($('#tags-edit-button')).not.toBeVisible();
        $('#tags-cancel-button').click();
        
        expect($('#tags-save-button')).not.toBeVisible();
        expect($('#tags-cancel-button')).not.toBeVisible();
        expect($('#tags-edit-button')).toBeVisible();
      });

      it('refreshes page with new tags if user clicks save', () => {
        var doneSpy = jasmine.createSpy();
        var postSpy = spyOn($, 'post').and.returnValue({ done: doneSpy });
        $('#tags-save-button').click();
        
        expect(postSpy.calls.argsFor(0)).toEqual([
          '/tag/endpoint',
          {tags: {ids: ['1', '2']}}
        ]);
        
        expect(doneSpy).toHaveBeenCalled();
      });

      // pending permissions card
      it('does not show an x inside tags that a user cannot remove');
      it('does not show tag options to a user who may not tag');
      
    });
  });

});