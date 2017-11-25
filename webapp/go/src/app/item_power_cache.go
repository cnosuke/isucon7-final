package main

import (
	"math/big"

	"log"
	"strconv"

	"io/ioutil"

	"fmt"
	"os"

	"github.com/k0kubun/pp"
	"gopkg.in/yaml.v2"
)

type Exp2 struct {
	// Mantissa * 10 ^ Exponent
	Mantissa int64 `yaml:"m"`
	Exponent int64 `yaml:"e"`
}

func (e *Exp2) exp2big() *big.Int {
	i := big.NewInt(e.Mantissa)
	ex := new(big.Int).Mul(big.NewInt(10), big.NewInt(e.Exponent))

	return i.Add(i, ex)
}

func big2exp2(n *big.Int) Exp2 {
	s := n.String()

	if len(s) <= 15 {
		return Exp2{n.Int64(), 0}
	}

	t, err := strconv.ParseInt(s[:15], 10, 64)
	if err != nil {
		log.Panic(err)
	}
	return Exp2{t, int64(len(s) - 15)}
}

type ItemPowerCache struct {
	ItemId       int `yaml:"item_id"`
	Powers       map[int]*Exp2
	BigIntPowers map[int]*big.Int
}

func LoadItemPowerCache() []*ItemPowerCache {
	// /Users/cnosuke/dev/src/github.com/cnosuke/isucon7-final/webapp/go/src/app/out.json"
	jsonPathPre := os.Getenv("JSON_CACHE_DIR_PREFIX")
	if jsonPathPre == "" {
		jsonPathPre = "/home/isucon/data/"
	}

	bytes, err := ioutil.ReadFile(fmt.Sprintf("%s/out.json", jsonPathPre))

	if err != nil {
		log.Fatal(err)
	}

	list := make([]*ItemPowerCache, 13)

	var tmpList []ItemPowerCache

	err = yaml.Unmarshal(bytes, &tmpList)
	if err != nil {
		log.Fatal(err)
	}

	for i, v := range tmpList {
		plist := make(map[int]*big.Int, len(v.Powers))

		for j, p := range v.Powers {
			plist[j] = p.exp2big()
		}

		pp.Println(i)
		list[i] = &ItemPowerCache{
			ItemId:       v.ItemId,
			BigIntPowers: plist,
		}

	}

	return list
}

var LoadedItemPowerCache = LoadItemPowerCache()

//func main() {
//rs := create_cache()

//b := []byte(rs)

//fmt.Println(rs)

//var newList []ItemPowerCache
//yaml.Unmarshal(b, &newList)
//
//for _, v := range newList {
//	for _, p := range v.Powers {
//		p.exp2big()
//	}
//}
//
//c := LoadedItemPowerCache
//pp.Println(c)
//}

//type mItem2 struct {
//	ItemID       int
//	Power1       int64
//	Power2       int64
//	Power3       int64
//	Power4       int64
//	Price1       int64
//	Price2       int64
//	Price3       int64
//	Price4       int64
//	PowerByCount map[int]*Exp2
//	PriceByCount map[int]*Exp2
//}

//func create_cache() string {
//	cacheNum := 200
//	mItemById := make(map[int]mItem2, 13)
//	mItemById[1] = mItem2{1, 0, 1, 0, 1, 0, 1, 1, 1, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[2] = mItem2{2, 0, 1, 1, 1, 0, 1, 2, 1, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[3] = mItem2{3, 1, 10, 0, 2, 1, 3, 1, 2, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[4] = mItem2{4, 1, 24, 1, 2, 1, 10, 0, 3, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[5] = mItem2{5, 1, 25, 100, 3, 2, 20, 20, 2, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[6] = mItem2{6, 1, 30, 147, 13, 1, 22, 69, 17, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[7] = mItem2{7, 5, 80, 128, 6, 6, 61, 200, 5, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[8] = mItem2{8, 20, 340, 180, 3, 9, 105, 134, 14, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[9] = mItem2{9, 55, 520, 335, 5, 48, 243, 600, 7, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[10] = mItem2{10, 157, 1071, 1700, 12, 157, 625, 1000, 13, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[11] = mItem2{11, 2000, 7500, 2600, 3, 2001, 5430, 1000, 3, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[12] = mItem2{12, 1000, 9000, 0, 17, 963, 7689, 1, 19, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//	mItemById[13] = mItem2{13, 11000, 11000, 11000, 23, 10000, 2, 2, 29, make(map[int]*Exp2, cacheNum), make(map[int]*Exp2, cacheNum)}
//
//	var list []ItemPowerCache
//
//	for _, item := range mItemById {
//		for count := 0; count < cacheNum; count++ {
//			exp := big2exp2(
//				item.GetPowerWithoutCache(count),
//			)
//
//			item.PowerByCount[count] = &exp
//
//			item.PriceByCount[count] = item.GetPriceWithoutCache(count)
//		}
//
//		c := ItemPowerCache{
//			ItemId: item.ItemID,
//			Powers: item.PowerByCount,
//		}
//
//		list = append(list, c)
//	}
//
//	bytes, _ := yaml.Marshal(list)
//
//	return string(bytes)
//}
//
//func (item *mItem2) GetPowerWithoutCache(count int) *big.Int {
//	// power(x):=(cx+1)*d^(ax+b)
//	a := item.Power1
//	b := item.Power2
//	c := item.Power3
//	d := item.Power4
//	x := int64(count)
//
//	s := big.NewInt(c*x + 1)
//	t := new(big.Int).Exp(big.NewInt(d), big.NewInt(a*x+b), nil)
//	return new(big.Int).Mul(s, t)
//}
//
//func (item *mItem2) GetPriceWithoutCache(count int) *big.Int {
//	// price(x):=(cx+1)*d^(ax+b)
//	a := item.Price1
//	b := item.Price2
//	c := item.Price3
//	d := item.Price4
//	x := int64(count)
//
//	s := big.NewInt(c*x + 1)
//	t := new(big.Int).Exp(big.NewInt(d), big.NewInt(a*x+b), nil)
//	return new(big.Int).Mul(s, t)
//}
