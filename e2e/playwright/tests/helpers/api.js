/**
 * api.js — backward-compatibility re-export.
 * New specs should import from ./common directly.
 */
const { loginApi, createMarketViaAdminApi } = require('./common');

module.exports = {
  loginApi,
  createMarketViaAdminApi,
};
