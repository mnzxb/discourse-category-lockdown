import { withPluginApi } from 'discourse/lib/plugin-api';

function initializeWithApi(api) {
  
  const clickhandler = function(e) {
    if (api.container.lookup('controller:topic').get('model.lockdown')) {
      bootbox.alert('抱歉，该分类下的资源只对群组内部成员开放，请联系群组管理员。');
      e.stopImmediatePropagation();
      return false;
    }
  }

  api.modifyClass('component:discourse-topic', {
    didInsertElement: function() {
      $(this.element).on('click', 'a.attachment', clickhandler);
      this._super(...arguments);
    }
  });

}

export default {
  name: 'lockdown-popup',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');

    if (siteSettings.category_lockdown_enabled) {
      withPluginApi('0.4', initializeWithApi);
    }

  }
};
