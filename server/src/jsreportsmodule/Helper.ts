export const defaultHelper = `

function getBwipJs() {
    return require('bwip-js');
}

`;

const handlerBarsHelper = `

const handlebars = require('handlebars');

const helpers = require('handlebars-helpers')({
  handlebars: handlebars
});

function iff(a, operator, b, opts) {
    var bool = false;
    switch (operator) {
        case '==':
            bool = a == b;
            break;
        case '===':
            bool = a === b;
            break;
        case '>':
            bool = a > b;
            break;
        case '>=':
            bool = a >= b;
            break;
        case '<':
            bool = a < b;
            break;
        case '<=':
            bool = a <= b;
            break;
        case 'in':
            bool = (Array.isArray(b) ? b : JSON.parse(b)).indexOf(a) > -1;
            break;
        case 'not in':
            bool = (Array.isArray(b) ? b : JSON.parse(b)).indexOf(a) === -1;
            break;
        default:
            throw "Unknown operator " + operator;
    }
    if (bool) {
        return opts.fn(this);
    } else {
        return opts.inverse(this);
    }
}

function isEmpty(value, opts) {
    if ((value == null ||
        (value === "") ||
        (Array.isArray(value) && value.length === 0))) {
        return opts.fn(this);
    } else {
        return opts.inverse(this);
    }
}

function isExist(value, opts) {
    if ((value == null ||
        (value === "") ||
        (Array.isArray(value) && value.length === 0))) {
        return opts.inverse(this);
    } else {
        return opts.fn(this);
    }
}

function eachGroup (a, group, opts) {
    if (a && a.length) {
            var groupArr = a.reduce((res, val, index) => {
                var obj = res[val[group]];
                if (obj) {
                    obj.array.push(val);
                } else {
                    res[val[group]] = {
                        array: [val],
                        index,
                    };
                }
                return res;
            }, {});
          let arr = Object.values(groupArr);
          arr.sort((obj1, obj2) => obj2.index - obj1.index);
          return arr.map((g) => {
              return g.array.map((val) => {
                  return opts.fn(val);
              });
          });
        } else {
          return opts.inverse(this);
    }
}

`;

export const engineHelper = (engine) => {
    switch (engine) {
        case "handlebars":
            return handlerBarsHelper;
        default:
            return "";
    }
};
