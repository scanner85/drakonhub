-- Autogenerated with DRAKON Editor 1.32
require('strict').on()


local table = table
local string = string
local pairs = pairs
local ipairs = ipairs
local io = io
local pcall = pcall
local xpcall = xpcall
local debug = debug
local tostring = tostring
local tonumber = tonumber
local type = type
local clock = require("clock")
local math = require("math")
local log = require("log")
local digest = require("digest")
local fiber = require("fiber")
local json = require("json")
local fio = require("fio")
local os = os
local error = error
local print = print

local utf8 = require("lua-utf8")


local utils = require("utils")

local mail = require("mail")
local ej = require("ej")
local lic = require("lic")

local global_cfg = global_cfg
local external_creds = external_creds

setfenv(1, {}) 

local module = nil

local globals = {}

function calculate_payment(num_users, product_id, old_license, pricing, now)
    -- item 29
    local result = {}
    -- item 44
    local users = tonumber(num_users)
    local limits = pricing.products[product_id]
    -- item 33
    if users then
        -- item 35
        if users >= limits.min_users then
            -- item 39
            if users <= limits.max_users then
                -- item 60
                local months = limits.period_mon
                local price = limits.price
                -- item 25
                local sum = round_cents(
                	price * users * months
                )
                -- item 30
                local period = utils.months_to_secs(months)
                 + days_to_secs(1)
                -- item 54
                result.sum = sum
                result.price = price
                result.period = period
                -- item 286
                local mva_rate = pricing.mva or 0
                local without_mva = 0
                -- item 46
                if (old_license) and (not (old_license.product_id == "basic")) then
                    -- item 62
                    local left = take_positive(
                    	old_license.expiry - now
                    )
                    -- item 266
                    local old_period = old_license.period or left
                    local old_sum = old_license.sum or 0
                    -- item 52
                    local remaining_value = left / old_period * old_sum
                    remaining_value = round_cents(remaining_value)
                    -- item 53
                    result.remaining_value = remaining_value
                    result.effective_start = now
                    without_mva = take_positive(sum - remaining_value)
                else
                    -- item 56
                    result.remaining_value = 0
                    result.effective_start = now
                    without_mva = sum
                end
                -- item 61
                result.expiry = result.effective_start
                 + period
                -- item 282
                result.mva = mva_rate * without_mva
                result.total = without_mva + result.mva
            else
                -- item 42
                result.error = "ERR_NUM_USERS_TOO_LARGE"
            end
        else
            -- item 38
            result.error = "ERR_NUM_USERS_TOO_LITTLE"
        end
    else
        -- item 34
        result.error = "ERR_NUM_USERS_SPECIFY"
    end
    -- item 32
    return result
end

function check_acc_number(fields, name, min, max)
    -- item 186
    local value = fields[name]
    -- item 187
    if type(value) == "string" then
        -- item 194
        if #value >= min then
            -- item 198
            if #value <= max then
                -- item 200
                local chars = utils.string_to_chars(value)
                for _, chr in ipairs(chars) do
                    -- item 203
                    if utils.is_digit(chr) then
                        
                    else
                        -- item 205
                        error("field '" .. name
                         .. "' contains non-digits: "
                         .. tostring(value)
                        )
                        break
                    end
                end
            else
                -- item 197
                error("field '" .. name
                 .. "' is too long: "
                 .. tostring(value)
                )
            end
        else
            -- item 196
            error("field '" .. name
             .. "' is too short: "
             .. tostring(value)
            )
        end
    else
        -- item 190
        error("field '" .. name
         .. "' is not a string: "
         .. tostring(value)
        )
    end
end

function check_card_type(type)
    -- item 2130001
    if ((type == "visa") or (type == "mastercard")) or (type == "amex") then
        
    else
        -- item 224
        error(
        	"unexpected card type: "
         .. tostring(type)
        )
    end
end

function check_int(fields, name, min, max)
    -- item 167
    local value = fields[name]
    -- item 168
    if type(value) == "number" then
        -- item 172
        if value == math.ceil(value) then
            -- item 175
            if value >= min then
                -- item 179
                if value <= max then
                    
                else
                    -- item 178
                    error("field '" .. name
                     .. "' is too large: "
                     .. tostring(value)
                    )
                end
            else
                -- item 177
                error("field '" .. name
                 .. "' is too small: "
                 .. tostring(value)
                )
            end
        else
            -- item 174
            error("field '" .. name
             .. "' is not an integer: "
             .. tostring(value)
            )
        end
    else
        -- item 171
        error("field '" .. name
         .. "' is not a number: "
         .. tostring(value)
        )
    end
end

function check_not_nil(fields, name)
    -- item 157
    if fields[name] == nil then
        -- item 160
        error("field '" .. name .. "' is nil")
    end
end

function days_to_secs(days)
    -- item 99
    return days * 24 * 3600
end

function get_or_request_token(trans_id)
    -- item 115
    local now = os.time()
    local message
    local description = ""
    -- item 116
    if ((globals.token) and (globals.expiry)) and (now < globals.expiry) then
        -- item 127
        return globals.token
    else
        -- item 128
        local call = {
        	url = make_paypal_url("/v1/oauth2/token"),
        	data = "grant_type=client_credentials",
        	mime = "application/x-www-form-urlencoded",
        	headers = make_paypal_headers(),
        	user = get_paypal_user()
        }
        -- item 129
        local result = utils.msgpack_call(
        	"localhost",
        	global_cfg.https_sender_port,
        	call
        )
        -- item 278
        if result then
            -- item 130
            ej.info(
            	"paypal_auth",
            	{url = call.url, trans_id=trans_id}
            )
            -- item 133
            if result.error then
                -- item 277
                message = result.error
                description = result.error_description
                -- item 136
                ej.info(
                	"paypal_auth_error",
                	{
                		url = call.url, trans_id=trans_id,
                		error = message,
                		error_description = description
                	}
                )
                -- item 132
                return nil
            else
                -- item 228
                if result.access_token then
                    -- item 131
                    globals.expiry = now + result.expires_in - 60
                    globals.token = result.access_token
                    -- item 127
                    return globals.token
                else
                    -- item 231
                    message = 
                    "access_token is missing"
                    -- item 136
                    ej.info(
                    	"paypal_auth_error",
                    	{
                    		url = call.url, trans_id=trans_id,
                    		error = message,
                    		error_description = description
                    	}
                    )
                    -- item 132
                    return nil
                end
            end
        else
            -- item 279
            message = "call to https_sender failed"
            -- item 136
            ej.info(
            	"paypal_auth_error",
            	{
            		url = call.url, trans_id=trans_id,
            		error = message,
            		error_description = description
            	}
            )
            -- item 132
            return nil
        end
    end
end

function get_paypal_user()
    -- item 280
    return external_creds.paypal_user
end

function make_paypal_headers()
    -- item 143
    local headers = {
    	"Accept: application/json",
    	"Accept-Language: en_US"
    }
    -- item 144
    return headers
end

function make_paypal_url(path)
    -- item 126
    return global_cfg.paypal_address .. path
end

function months_to_secs(months)
    -- item 92
    local secs_in_month = 3600 * 24 * 365.25 / 12
    -- item 93
    return utils.round(months * secs_in_month)
end

function pay_card(details, user_id)
    -- item 161
    check_not_nil(details, "trans_id")
    check_not_nil(details, "type")
    check_not_nil(details, "number")
    check_not_nil(details, "expire_year")
    check_not_nil(details, "expire_month")
    check_not_nil(details, "first_name")
    check_not_nil(details, "last_name")
    check_not_nil(details, "total")
    check_not_nil(details, "currency")
    check_not_nil(details, "description")
    -- item 206
    check_acc_number(details, "number", 13, 19)
    check_int(details, "cvv2", 0, 9999)
    -- item 207
    check_int(details, "expire_month", 1, 12)
    check_int(details, "expire_year", 2016, 2050)
    -- item 225
    check_card_type(details.type)
    -- item 274
    local total = utils.print_amount(details.total)
    -- item 248
    local result
    -- item 226
    local access_token = get_or_request_token(
    	details.trans_id
    )
    -- item 244
    if access_token then
        -- item 250
        local payment = {
        	intent = "sale",
        	payer = {
        		payment_method = "credit_card",
        		funding_instruments = {
        			{
        				credit_card = {
        					number = details.number,
        					type = details.type,
        					expire_month = details.expire_month,
        					expire_year = details.expire_year,
        					cvv2 = details.cvv2,
        					first_name = details.first_name,
        					last_name = details.last_name
        				}
        			}
        		}
        	},
        	transactions = {
        		{
        			reference_id = trans_id,
        			amount = {
        				total = total,
        				currency = details.currency
        			},
        			description = details.description:sub(1, 127)
        		}
        	}
        }
        -- item 254
        local headers = make_paypal_headers()
        table.insert(
        	headers,
        	"Authorization: Bearer " .. access_token
        )
        -- item 255
        local body = {
        	url = make_paypal_url("/v1/payments/payment"),
        	data = payment,
        	headers = headers
        }
        -- item 260
        ej.info(
        	"paypal_pay",
        	{url = body.url, trans_id=details.trans_id,
        	user_id=user_id,
        	total=total, currency=details.currency}
        )
        -- item 256
        result = utils.msgpack_call(
        	"localhost",
        	global_cfg.https_sender_port,
        	body
        )
        -- item 257
        if result then
            -- item 263
            if result.state == "approved" then
                -- item 267
                ej.info(
                	"paypal_pay_success",
                	{url = body.url, trans_id=details.trans_id,
                	card_type = details.type, user_id = user_id,
                	total=total, currency=details.currency}
                )
            else
                -- item 265
                local err_info = json.encode(result)
                  .. " trans_id=" .. details.trans_id
                -- item 261
                ej.info(
                	"paypal_pay_error",
                	{url = body.url, trans_id=details.trans_id,
                	paypal_error=result,
                	card_type = details.type, user_id = user_id,
                	total=total, currency=details.currency}
                )
                -- item 262
                log.error("paypal_pay_error: " .. err_info)
            end
        else
            -- item 264
            result = {}
            -- item 265
            local err_info = json.encode(result)
              .. " trans_id=" .. details.trans_id
            -- item 261
            ej.info(
            	"paypal_pay_error",
            	{url = body.url, trans_id=details.trans_id,
            	paypal_error=result,
            	card_type = details.type, user_id = user_id,
            	total=total, currency=details.currency}
            )
            -- item 262
            log.error("paypal_pay_error: " .. err_info)
        end
    else
        -- item 246
        log.error(
        	"authorization failed: "
        	 .. details.trans_id)
        -- item 249
        result = nil
    end
    -- item 227
    return result
end

function px2_calculate_payment(num_users, product_id, pricing)
    -- item 322
    local result = {}
    -- item 323
    local users = tonumber(num_users)
    local limits = pricing.products[product_id]
    -- item 300
    if users then
        -- item 302
        if users >= limits.min_users then
            -- item 306
            if users <= limits.max_users then
                -- item 317
                local price = limits.price
                -- item 318
                result.price = price
                -- item 319
                local mva_rate = pricing.mva or 0
                -- item 295
                local total = round_cents(
                	price * users
                )
                -- item 313
                result.sum = round_cents_down(
                	total / (1 + mva_rate)
                )
                -- item 320
                result.mva = round_cents(total - result.sum)
                result.total = total
            else
                -- item 309
                result.error = "ERR_NUM_USERS_TOO_LARGE"
            end
        else
            -- item 305
            result.error = "ERR_NUM_USERS_TOO_LITTLE"
        end
    else
        -- item 301
        result.error = "ERR_NUM_USERS_SPECIFY"
    end
    -- item 299
    return result
end

function round_cents(amount)
    -- item 69
    return utils.round(amount, 2)
end

function round_cents_down(amount)
    -- item 337
    local result = math.floor(amount * 100) / 100
    -- item 338
    return result
end

function take_positive(number)
    -- item 86
    return math.max(0, number)
end


module = {
	calculate_payment = calculate_payment,
	px2_calculate_payment = px2_calculate_payment,
	pay_card = pay_card
}

return module
