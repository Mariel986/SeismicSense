using UnityEngine;

public class Stick : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {

    }

    void OnCollisionEnter(Collision collision)
    {
        SeismicSense.Instance.AddWave(collision.contacts[0].point);
        GetComponent<AudioSource>().Play();
    }
}
