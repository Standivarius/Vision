"""A02 three-/four-display role resolver. Does not change four-screen oracle."""
from win_observer import monitors


def roles(displays):
    primary=[x for x in displays if x.get("primary")]
    others=sorted(
        (x for x in displays if not x.get("primary")),
        key=lambda x:x["bounds"]["left"]
    )
    if len(primary)!=1 or len(others) not in (2,3):
        return {}
    result={"LAPTOP":primary[0], "CENTRE":others[-2], "RIGHT":others[-1]}
    if len(others)==3:
        result["LEFT"]=others[0]
    if not all(result[key]["bounds"]["right"] > result[key]["bounds"]["left"]
               for key in result):
        return {}
    return result
