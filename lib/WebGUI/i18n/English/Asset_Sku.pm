package WebGUI::i18n::English::Asset_Sku;

use strict;

our $I18N = { 
	'sku properties title' => { 
		message => q|Sku Properties|,
		lastUpdated => 0, 
		context => q|a help label|
	},

	'cancel recurring message' => {
		message 	=> q|Recurring transaction %s with an item named %s for a user named %s has been cancelled.|,
		lastUpdated	=> 0,
		context		=> q|a notification email sent to shop owners|,
	},
	
	'shop' => { 
		message => q|Shop|,
		lastUpdated => 0, 
		context => q|The name of a tab that all Sku based assets have to put their commerce related settings.|
	},

	'display title' => {
		message => q|Display Title?|,
		lastUpdated => 0,
		context => q|propertly label|
	},

	'display title help' => {
		message => q|Indicate whether the title should be displayed or not.|,
		lastUpdated => 0,
		context => q|property label help|
	},

	'description' => {
		message => q|Description|,
		lastUpdated => 0,
		context => q|The label for the description of the product.|
	},

	'description help' => {
		message => q|Describe the product or service here.|,
		lastUpdated => 0,
		context => q|help for description field|
	},

	'sku' => {
		message => q|SKU|,
		lastUpdated => 0,
		context => q|Abbreviation for "Stock Keeping Unit" which is used as a product number or other such record keeping number.|
	},

	'sku help' => {
		message => q|Stands for Stock Keeping Unit, which is just a fancy term for an inventory code or product number.|,
		lastUpdated => 0,
		context => q|help for sku field|
	},

	'vendor' => {
		message => q|Vendor|,
		lastUpdated => 0,
		context => q|asset field relating to who is selling this product|
	},

	'vendor help' => {
		message => q|Which person/company defined in the commerce system should get credit for selling this item, if any?|,
		lastUpdated => 0,
		context => q|help for vendor field|
	},

	'override tax rate' => {
		message => q|Override tax rate?|,
		lastUpdated => 0,
		context => q|A yes/no field asking whether to override tax rate.|
	},

	'override tax rate help' => {
		message => q|Would you like to override the default tax rate for this item? Usually used in locales that have special or no tax on life essential items like food and clothing.|,
		lastUpdated => 0,
		context => q|help for override tax rate field|
	},

	'tax rate override' => {
		message => q|Tax Rate Override|,
		lastUpdated => 0,
		context => q|a field containing the percentage to use to calculate tax for this item|
	},

	'tax rate override help' => {
		message => q|What is the new percentage that should be used to calculate tax on this item?|,
		lastUpdated => 0,
		context => q|help for tax rate override field|
	},

	'Add a Variant' => {
		message => q|Add a Variant|,
		lastUpdated => 0,
		context => q|i18n label for the view template|
	},

	'Set Product price and SKU' => {
		message => q|Set Product price and SKU|,
		lastUpdated => 0,
		context => q|i18n label for the view template|
	},

	'assetName' => {
		message => q|Sku|,
		lastUpdated => 0,
        context => "The name of this asset."
	},

};

1;
